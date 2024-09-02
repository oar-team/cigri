#!/usr/bin/ruby -w
#
# This library contains the classes used by the runner module
#

require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-iolib'

CONF=Cigri.conf unless defined? CONF
RUNNERLIBLOGGER = Cigri::Logger.new('RUNNERLIB', CONF.get('LOG_FILE'))

RUNNER_TAP_INCREASE_FACTOR=CONF.get('RUNNER_TAP_INCREASE_FACTOR',"1.5").to_f
RUNNER_TAP_INCREASE_MAX=CONF.get('RUNNER_TAP_INCREASE_MAX',"100").to_i
RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS=CONF.get('RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS',"2").to_i
RUNNER_TAP_GRACE_PERIOD=CONF.get('RUNNER_TAP_GRACE_PERIOD',"60").to_i
RUNNER_MAX_TEMPORAL_GROUPED_JOBS=CONF.get('RUNNER_MAX_TEMPORAL_GROUPED_JOBS',"50").to_i

module Cigri


  # Runner class
  # A runner instance is an iteration of the runner module
  # on a given cluster
  class Runner
    attr_reader :cluster

    # Creates a new runner instance
    def initialize(cluster)
      @cluster=cluster
      #@dbh=db_connect()
    end
  end

  # Tap class
  # A tap allows job flow control for campaigns on clusters.
  # There's a tap per campaign on each cluster. A tap may be open or closed.
  # A tap has a flow rate (an integer value) that represents the number
  # of jobs that are submitted at once. The rate may be increased or decreased
  # by a factor. When the tap is closed, the rate is kept but the closing
  # date is registered so that we can reset the rate to the minimum value
  # if the tap is closed for too long.
  class Tap < Datarecord
    attr_reader :props
    
    # Creates a new tap or get it from the database
    def initialize(props={})
      @table="taps"
      @index="id"
      # If id is given, get it
      if props[:id]
        @props=get_record(@table,props[:id],"*")
      elsif props[:cluster_id] and props[:campaign_id]
        # Try to get it
        dbh = db_connect()
        @props = get_tap(dbh,props[:cluster_id],props[:campaign_id])
        dbh.disconnect
        #or create it
        if @props.nil?
          @props=props
          @props[:rate]=RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS
          @props[:state]="open"
          @props[:id]=new_record(@table,props)
        end
      else
        raise Cigri::Error,("No id, or cluster_id+campaign_id provided for tap!")
      end
    end

    # Return true if the tap is open
    def open?
      @props[:state]=='open'
    end

    # Open a tap
    def open
      if not open?
        RUNNERLIBLOGGER.info("Opening tap of campaign #{@props[:campaign_id]} on cluster #{@props[:cluster_id]}")
        update!({:state => 'open'}) 
      end
    end

    # Close a tap
    def close
      if open?
        RUNNERLIBLOGGER.info("Closing tap of campaign #{@props[:campaign_id]} on cluster #{@props[:cluster_id]}")
        update!({:state => 'closed', :close_date => Time::now.to_s})
      end
    end 

    # Increase the rate of a tap
    def increase
      campaign=Campaign.new(:id => @props[:campaign_id])
      campaign.get_clusters()
      runner_options=campaign.get_runner_options(@props[:cluster_id])
      # Temporal grouping case: the tap is used to set the number of subjobs of the batch
      if runner_options["temporal_grouping"] == true
        average_job_duration=campaign.average_job_duration()[0].to_i
        batch_wanted_duration=900
        if runner_options["temporal_grouping_batch_duration"]
          batch_wanted_duration=runner_options["temporal_grouping_batch_duration"].to_i
        end
        if average_job_duration > 0
          batch_size=(batch_wanted_duration/average_job_duration).round(half: :up)+1
          if batch_size > RUNNER_MAX_TEMPORAL_GROUPED_JOBS
            batch_size = RUNNER_MAX_TEMPORAL_GROUPED_JOBS
          end
        else
          batch_size=RUNNER_MAX_TEMPORAL_GROUPED_JOBS
        end
        update!({:rate => batch_size})
      # Normal case  
      else
        curr_rate=@props[:rate].to_i
        if curr_rate < RUNNER_TAP_INCREASE_MAX
          curr_rate=(curr_rate*RUNNER_TAP_INCREASE_FACTOR).to_i
          curr_rate=RUNNER_TAP_INCREASE_MAX if curr_rate > RUNNER_TAP_INCREASE_MAX
          RUNNERLIBLOGGER.info("Increasing tap of campaign #{@props[:campaign_id]} on cluster #{@props[:cluster_id]} to #{curr_rate}")
          update!({:rate => curr_rate})
        end
      end
    end

    # Reset a tap rate to the default value
    def reset
       update!({:rate => RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS})
    end

    # Decrease the rate of a tap
    def decrease
      # Dont decrease during grace period
      refresh!
      return if @props[:close_date] and (Time::now().to_i - Time.parse(@props[:close_date]).to_i) < RUNNER_TAP_GRACE_PERIOD
      curr_rate=@props[:rate].to_i
      if curr_rate > RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS
        curr_rate=(curr_rate/RUNNER_TAP_INCREASE_FACTOR).to_i
        curr_rate=RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS if curr_rate < RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS
        RUNNERLIBLOGGER.info("Decreasing tap of campaign #{@props[:campaign_id]} on cluster #{@props[:cluster_id]} to #{curr_rate}")
        update!({:rate => curr_rate})
      end
    end

  end # Tap class

end # Cigri module
