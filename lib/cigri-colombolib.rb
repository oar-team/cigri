#!/usr/bin/ruby -w
#
# This library contains Colombo methods.
# It's intended to do some actions depending on events
#

require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-eventlib'

CONF=Cigri.conf unless defined? CONF
COLOMBOLIBLOGGER = Cigri::Logger.new('COLOMBOLIB', CONF.get('LOG_FILE'))
if CONF.exists?('STDERR_TAIL')
  STDERR_TAIL = CONF.get('STDERR_TAIL').to_i
else
  STDERR_TAIL = 5 
end

module Cigri


  # Colombo class
  class Colombo
    attr_reader :events

    # Creates a new colombo instance over an Eventset
    def initialize(events=nil)
      if (events.class.to_s == "NilClass")
        get_all_open_events
      elsif (events.class.to_s == "Cigri::Event")
        e=[]
        e << events
        @events=Cigri::Eventset.new(:values => e)
      elsif (events.class.to_s == "Cigri::Eventset")
        @events=events
      else
        raise Cigri::Error, "Can't initiate a colombo instance with a #{events.class.to_s}!"
      end
    end

    def get_all_open_events
      @events=Cigri::Eventset.new(:where => "state='open' and checked = 'no'")
    end

    # Blacklist a cluster
    def blacklist_cluster(parent_id,cluster_id,campaign_id=nil)
      if campaign_id.nil?
        Cigri::Event.new(:class => "cluster", :code => "BLACKLIST", :cluster_id => cluster_id, :parent => parent_id)
      else
        Cigri::Event.new(:class => "campaign", :code => "BLACKLIST", :cluster_id => cluster_id, :campaign_id => campaign_id, :parent => parent_id)
      end
    end



    #### Check methods that may be called by the cigri modules ####

    # Check cluster errors and blacklist the cluster if necessary
    def check_clusters
      COLOMBOLIBLOGGER.debug("Checking cluster events")
      @events.each do |event|
        if event.props[:class]=="cluster"
          COLOMBOLIBLOGGER.debug("Checking event #{event.props[:code]}")
          case event.props[:code]
          when "TIMEOUT", "CONNECTION_REFUSED", "SUBMIT_JOB", "GET_JOBS", "GET_JOB", "GET_MEDIA"
            blacklist_cluster(event.id,event.props[:cluster_id],event.props[:campaign_id])
            event.checked
          when "DELETE_JOB"
            if event.props[:message].include?("This job was already killed")
              COLOMBOLIBLOGGER.debug("Closing alright event #{event.id} for an already killed job}")
              event.close
            else
              blacklist_cluster(event.id,event.props[:cluster_id],event.props[:campaign_id])
            end
            event.checked
          else
          end
        end
      end
    end
   
    # Try to automatically fix some events
    def autofix_clusters
      COLOMBOLIBLOGGER.debug("Autofixing clusters")
      @events.each do |event|
        #TODO: add a field date_update into events so that we can check
        # only after a given amount of time
        if event.props[:class]=="cluster"
          if event.props[:code] == "TIMEOUT" or event.props[:code] == "CONNECTION_REFUSED"
            cluster=Cluster.new({:id => event.props[:cluster_id]})
            if cluster.check_api?
              COLOMBOLIBLOGGER.debug("Autofixing #{cluster.name}")
              event.checked
              event.close
            end
          end
        end
      end
    end

    # Remove a blacklist if the parent event is fixed
    def check_blacklists
      COLOMBOLIBLOGGER.debug("Checking blacklists")
      @events.each do |event|
        if event.props[:code] == "BLACKLIST"
          parent_event=Event.new({:id => event.props[:parent]})
          if parent_event.props[:state] == "closed"
            COLOMBOLIBLOGGER.debug("Removing blacklist for cluster #{event.props[:cluster_id]} on event #{parent_event.props[:code]}")
            event.checked
            event.close
          end
        end
      end
    end

    # Resubmit the jobs that are stuck into the launching state
    def check_launching_jobs
      COLOMBOLIBLOGGER.debug("Checking launching jobs")
      @events.each do |event|
        if event.props[:class]=="job" and event.props[:code] == "STUCK_LAUNCHING_JOB"
          job=Job.new({:id => event.props[:job_id], :state => 'event'})
          COLOMBOLIBLOGGER.warn("Resubmitting job #{job.id} as it was stuck into launching state")
          event.update({:message => event.props[:message].to_s+";Colombo resubmit at "+Time::now().to_s+"for stuck into launching state"})
          event.checked
          job.resubmit
          event.close
        end
      end
    end

    # Take some decisions by analyzing remote job events (OAR events actually)
    # This is where we decide to automatically resubmit a job when it was killed
    def self.analyze_remote_job_events(job,cluster_job)
      resubmit=false
      type=''
      # Automatic resubmit with the special exit status 66
      if (cluster_job["exit_code"] >> 8) == 66
        resubmit=true
        type="Special_exit_status_66"
      # Automatic resubmit with the special exit status 67 (job placed at the end of the queue)
      elsif (cluster_job["exit_code"] >> 8) == 67
        resubmit=true
        type="Special_exit_status_67"
      # Automatic resubmit when the job was killed
      else
        cluster_job["events"].each do |remote_event|
          type=remote_event["type"] 
          if type == "FRAG_JOB_REQUEST" or type == "BESTEFFORT_KILL"
            resubmit=true
            break
          end
        end
      end
      # Treat resubmission
      if resubmit
        if type == "Special_exit_status_67"
          code="RESUBMIT_END"
        else
          code="RESUBMIT"
        end
        COLOMBOLIBLOGGER.debug("Creating a RESUBMIT event for job #{job.id}")
        Cigri::Event.new(:class => "job", 
                         :code => code, 
                         :job_id => job.id, 
                         :cluster_id => job.props[:cluster_id], 
                         :message => "Resubmit cause: #{type}")
      # Other errors (exit status)
      elsif (cluster_job["exit_code"] >> 8) > 0
        COLOMBOLIBLOGGER.debug("Creating a EXIT_ERROR event for job #{job.id}")
        # Get the STDERR output file
        cluster=Cluster.new({:id => job.props[:cluster_id]})
        stderr_file=cluster_job["launching_directory"]+"/"+cluster_job["stderr_file"]
        begin
          stderr=cluster.get_file(stderr_file,job.props[:grid_user],STDERR_TAIL)
        rescue => e
          stderr=''
          COLOMBOLIBLOGGER.warn("Could not get the stderr file #{stderr_file} for failed job #{job.id}: #{e.to_s}")
        end
        # Create event
        Cigri::Event.new(:class => "job",
                         :code => "EXIT_ERROR",
                         :job_id => job.id,
                         :cluster_id => job.props[:cluster_id], 
                         :message => "The job exited with exit status #{cluster_job["exit_code"] >> 8}; stderr_file:#{stderr}")
      # Unknown errors
      else 
        COLOMBOLIBLOGGER.debug("Creating a UNKNOWN_ERROR event for job #{job.id}")
        Cigri::Event.new(:class => "job",
                         :code => "UNKNOWN_ERROR",
                         :job_id => job.id,
                         :cluster_id => job.props[:cluster_id], 
                         :message => "The job exited with an unknown error. Job events: #{cluster_job["events"].inspect}")
      end
      job.update({:state => 'event'})
    end

    # Check the jobs
    def check_jobs
      COLOMBOLIBLOGGER.debug("Checking jobs") 
      @events.each do |event|

        # Treat resubmissions
        if ( event.props[:class] == "job" and 
              ( event.props[:code] == "RESUBMIT" or event.props[:code] == "RESUBMIT_END" ) and
              event.props[:checked] == "no" )
          event.checked
          job=Job.new(:id => event.props[:job_id])
          COLOMBOLIBLOGGER.info("Resubmitting job #{job.id}")
          if event.props[:code] == "RESUBMIT_END"
            job.resubmit_end
          else
            job.resubmit
          end 
          event.close

        # Treat other errors (blacklist cluster for campaign)
        elsif ( event.props[:class] == "job" and 
                  event.props[:checked] == "no" )
          event.checked
          job=Job.new(:id => event.props[:job_id])
          blacklist_cluster(event.id,job.props[:cluster_id],job.props[:campaign_id])
        end
      end
    end

    # Do some default checking
    def check
      COLOMBOLIBLOGGER.debug("Global check requested")
      check_clusters
      check_launching_jobs
    end

  end
end
