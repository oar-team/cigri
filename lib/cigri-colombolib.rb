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
        Cigri::Event.new(:class => "cluster", :code => "BLACKLIST", :cluster_id => cluster_id, :campaign_id => campaign_id, :parent => parent_id)
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
          when "SUBMIT_JOB"
            blacklist_cluster(event.id,event.props[:cluster_id],event.props[:campaign_id])
            event.checked
          when "GET_JOB"
            blacklist_cluster(event.id,event.props[:cluster_id],event.props[:campaign_id])
            event.checked
          else
          end
        end
      end
    end

    # Remove a blacklist if the parent event is fixed
    def check_blacklists
      COLOMBOLIBLOGGER.debug("Checking blacklists")
      @events.each do |event|
        if event.props[:class]=="cluster" and event.props[:code] == "BLACKLIST"
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
          job.resubmit
          event.checked
          event.close
        end
      end
    end

    def check
      COLOMBOLIBLOGGER.debug("Global check requested")
      check_clusters
      check_launching_jobs
    end

  end
end
