#!/usr/bin/ruby -w
#
# This library contains Colombo methods.
# It's intended to do some actions depending on events
#

require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-eventlib'
require 'cigri-iolib'
require 'cigri-notificationlib'
require 'cigri-joblib'

CONF=Cigri.conf unless defined? CONF
COLOMBOLIBLOGGER = Cigri::Logger.new('COLOMBOLIB', CONF.get('LOG_FILE'))
if CONF.exists?('STDERR_TAIL')
  STDERR_TAIL = CONF.get('STDERR_TAIL').to_i
else
  STDERR_TAIL = 5 
end
if CONF.exists?('AUTOFIX_DELAY')
  AUTOFIX_DELAY = CONF.get('AUTOFIX_DELAY').to_i
else
  AUTOFIX_DELAY = 30
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
      # Fill a hash with the current campaign users
      campaigns=Cigri::Campaignset.new
      campaigns.get_unfinished
      @campaign_users=campaigns.get_users
      # Fill a hash with the cluster names
      @cluster_names = {}
      clusters=Cigri::ClusterSet.new
      clusters.each do |cluster|
       @cluster_names[cluster.id]=cluster.name
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

    # Check the database
    # Make some checks of the database (used at startup)
    def self.check_database
      db_connect() do |dbh|
        check_null_parameter(dbh)
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
          when "TIMEOUT", "CONNECTION_RESET", "CONNECTION_REFUSED", "SSL_ERROR", "SUBMIT_JOB", "GET_JOBS", "GET_JOB", "GET_MEDIA"
            blacklist_cluster(event.id,event.props[:cluster_id],event.props[:campaign_id])
            event.checked
          when "PERMISSION_DENIED", "FORBIDDEN"
            # This is an event that may be specific to a user, so we do not blacklist the cluster
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
        if event.props[:class]=="cluster"
          if  ( event.props[:code] == "TIMEOUT" ||
                event.props[:code] == "CONNECTION_REFUSED" ||
                event.props[:code] == "CONNECTION_RESET" ||
                event.props[:code] == "SSL_ERROR"
              ) && (Time.now.to_i - Time.parse(event.props[:date_update]).to_i) > AUTOFIX_DELAY
            event.checked
            cluster=Cluster.new({:id => event.props[:cluster_id]})
            if cluster.check_api?
              COLOMBOLIBLOGGER.debug("Autofixing #{cluster.name}")
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
      if (!cluster_job["exit_code"].nil? && cluster_job["exit_code"].to_i >> 8) == 66
        resubmit=true
        type="Special_exit_status_66"
      # Automatic resubmit with the special exit status 67 (job placed at the end of the queue)
      elsif (!cluster_job["exit_code"].nil? && cluster_job["exit_code"].to_i >> 8) == 67
        resubmit=true
        type="Special_exit_status_67"
      # Automatic resubmit when the job was killed
      else
        cluster_job["events"].each do |remote_event|
          type=remote_event["type"] 
          if type == "EXTERMINATE" or type == "WALLTIME" or type == "FRAG_JOB_REQUEST" or type == "BESTEFFORT_KILL"
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
        COLOMBOLIBLOGGER.debug("Creating a #{code} event for job #{job.id}")
        Cigri::Event.new(:class => "job", 
                         :code => code, 
                         :job_id => job.id, 
                         :campaign_id => job.props[:campaign_id],
                         :cluster_id => job.props[:cluster_id], 
                         :message => "Resubmit cause: #{type}")
      # Other errors (exit status)
      elsif (!cluster_job["exit_code"].nil? && cluster_job["exit_code"].to_i >> 8) > 0
        case job.props[:tag]
          when "prologue"
            code="PROLOG_EXIT_ERROR"
          when "epilogue"
            code="EPILOG_EXIT_ERROR"
          else
            code="EXIT_ERROR"
        end        
        COLOMBOLIBLOGGER.debug("Creating a #{code} event for job #{job.id}")
        # Get the STDERR output file
        cluster=Cluster.new({:id => job.props[:cluster_id]})
        begin
          stderr_file=cluster_job["launching_directory"]+"/"+cluster_job["stderr_file"]
          stderr=cluster.get_file(stderr_file,job.props[:grid_user],STDERR_TAIL)
        rescue => e
          stderr=''
          COLOMBOLIBLOGGER.warn("Could not get the stderr file #{stderr_file} for failed job #{job.id}: #{e.to_s}")
        end
        # Create event
        message = "The job exited with exit status #{cluster_job["exit_code"].to_i >> 8};"
        message += "\nLast #{STDERR_TAIL} lines of stderr_file:\n#{stderr}" if stderr.length > 0
        Cigri::Event.new(:class => "job",
                         :code => code,
                         :job_id => job.id,
                         :campaign_id => job.props[:campaign_id],
                         :cluster_id => job.props[:cluster_id], 
                         :message => message)
      # Unknown errors
      else 
        COLOMBOLIBLOGGER.debug("Creating a UNKNOWN_ERROR event for job #{job.id}")
        Cigri::Event.new(:class => "job",
                         :code => "UNKNOWN_ERROR",
                         :job_id => job.id,
                         :campaign_id => job.props[:campaign_id],
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

    ## Count the events per campaign_id
    #
    def count_events_per_campaign(events)
      count_per_campaign={}
      events.each do |event|
      if count_per_campaign[event.props[:campaign_id].to_i].nil?
          count_per_campaign[event.props[:campaign_id].to_i]=1
        else
          count_per_campaign[event.props[:campaign_id].to_i]+=1
        end
      end
      return count_per_campaign
    end

    ##
    # Notify EXIT_ERROR events
    # Such events are grouped into one aggregated notification message
    #
    # == Parameters:
    # - im: instant message handlers hash
    #
    def notify_exit_errors!(im_handlers)
      events=@events.records.select{|event| event.props[:code]=="EXIT_ERROR" and event.props[:notified] == "f"}
      COLOMBOLIBLOGGER.debug("Notifying #{events.length} exit_error events") if events.length > 0
      count_events_per_campaign(events).each do |campaign_id,number| 
        message_props={
                        :subject => "#{number} exit errors on campaign ##{campaign_id}" ,
                        :message => "You have exit errors on campaign ##{campaign_id}. Please, check cigri events.",
                        :severity => 'high'
                      }
        message_props[:message]+="The first event says:\n"
        message_props[:message]+=events[0].props[:message]
        message_props[:user]=@campaign_users[campaign_id] unless @campaign_users[campaign_id].nil?
        message=Cigri::Message.new(message_props,im_handlers)
        # Actual sending of a grouped message
        begin
          message.send
        rescue => e
          COLOMBOLIBLOGGER.error("Error sending notification: #{e.message} #{e.backtrace}")
        end
      end
      events.each do |event| 
        event.notified!
      end
    end

    ##
    # Notify BLACKLIST events
    # Such events are grouped into one aggregated notification message
    #
    # == Parameters:
    # - im: instant message handlers hash
    #
    def notify_blacklists!(im_handlers)
      # Campaign blacklists (for users)
      events=@events.records.select{|event| event.props[:code]=="BLACKLIST" and event.props[:notified] == "f" and event.props[:campaign_id]}
      COLOMBOLIBLOGGER.debug("Notifying #{events.length} blacklist events") if events.length > 0
      campaigns=[]
      events.each do |event|
        campaign_id=event.props[:campaign_id].to_i
        if not campaigns.include?(campaign_id)
           message_props={
                        :subject => "Cluster ##{event.props[:cluster_id]} blacklisted for campaign ##{event.props[:campaign_id]} ",
                        :severity => "high",
                        :admin => true,
                        :message => "Cluster #{event.props[:cluster_id]} is blacklisted for campaign ##{event.props[:campaign_id]}, please check grid events for details"
                      }
          message_props[:user]=@campaign_users[campaign_id] unless @campaign_users[campaign_id].nil?
          message=Cigri::Message.new(message_props,im_handlers)
          begin
            message.send
          rescue => e
            COLOMBOLIBLOGGER.error("Error sending notification: #{e.message} #{e.backtrace}")
          end
        else
          campaigns << campaign_id
        end
        event.notified!
      end
      # Cluster blacklists (for admin)
      events=@events.records.select{|event| event.props[:code]=="BLACKLIST" and event.props[:notified] == "f" and !event.props[:campaign_id]}
      events.each do |event|
        message_props={
                        :subject => "Cluster #{event.props[:cluster_id]} blacklisted!",
                        :severity => "high",
                        :admin => true,
                        :message => "Cluster #{event.props[:cluster_id]} is blacklisted because of event #{event.props[:parent]}"
                      }
        message=Cigri::Message.new(message_props,im_handlers)
        begin
          message.send
        rescue => e
          COLOMBOLIBLOGGER.error("Error sending notification: #{e.message} #{e.backtrace}")
        end
        event.notified!
      end
    end

    ## Notify generic events
    # Sends a message per generic event
    #
    # == Parameters:
    # - im: instant message handlers hash
    #
    def notify_generic_events!(im_handlers)
      # Only notify events that are not already notified
      events=@events.records.select{|event| event.props[:notified] == "f"}
      COLOMBOLIBLOGGER.debug("Notifying #{events.length} generic events") if events.length > 0
      events.each do |event|
        message_props={
                        :subject => "New event ##{event.id}: #{event.props[:code]}" ,
                        :message => event.props[:message]
                      }
        # Classifying severity
        #   Informational events
        if ["FINISHED_CAMPAIGN","NEW_CAMPAIGN"].include?(event.props[:code])
          message_props[:severity]="low"
        #   Temporary or such events
        elsif ["TIMEOUT","CONNECTION_REFUSED","CONNECTION_RESET","SSL_ERROR"].include?(event.props[:code])
          message_props[:severity]="medium"
        #   Fatal events (lead to a blacklist until manually fixed)
        else
          message_props[:severity]="high"
        end
        # User events
        if event.props[:campaign_id]
          campaign_id=event.props[:campaign_id].to_i
          message_props[:user]=@campaign_users[campaign_id] unless @campaign_users[campaign_id].nil?
          message_props[:subject]+=" on cluster #{@cluster_names[event.props[:cluster_id].to_i]}" if event.props[:cluster_id]
          message_props[:subject]+=" for campaign ##{event.props[:campaign_id]}"
        # Admin events
        else 
          message_props[:admin]=true
        end
        message_props[:subject]+=" because of event ##{event.props[:parent]}" if event.props[:parent]
        message=Cigri::Message.new(message_props,im_handlers)
        # Actual sending
        begin
          message.send
          event.notified!
        rescue => e
          COLOMBOLIBLOGGER.error("Error sending notification: #{e.message} #{e.backtrace}")
        end
      end # events
    end

    # Some events should never be notified (internal events)
    # This methods removes such events from the @events array.
    def remove_not_to_be_notified_events!
      @events.each do |event|
        if ["RESUBMIT","RESUBMIT_END","FRAG"].include?(event.props[:code])
          @events.records.delete(event)
        end
      end
    end

    ##
    # Notify events
    #
    # == Parameters:
    # - im: instant message handlers hash
    #
    def notify(im_handlers)
      COLOMBOLIBLOGGER.debug("Notifying #{@events.length} events") if @events.length > 0
      remove_not_to_be_notified_events!
      notify_exit_errors!(im_handlers)
      notify_blacklists!(im_handlers)
      notify_generic_events!(im_handlers)
    end

  end

end
