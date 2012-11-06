#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-joblib'
require 'cigri-scheduler-fifo'
require 'cigri-eventlib'

$0='cigri: metascheduler'

begin
  config = Cigri.conf
  logger = Cigri::Logger.new('META-SCHEDULER', config.get('LOG_FILE'))
  
  %w{INT TERM}.each do |signal|
    Signal.trap(signal){ 
      #cleanup!
      logger.warn('Interruption caught: exiting.')
      exit(1)
    }
  end
  
  logger.debug('Starting')
  
  # Round robind metascheduling for now:
  # we just call the fifo scheduler for each campaign sequentially
  # on each cluster with a max number of jobs and only stop
  # when the bag-of-tasks is empty (queing everything is not exactly
  # what we want in the long term)
  max_jobs=10
  campaigns=Cigri::Campaignset.new
  campaigns.get_running
  campaigns.each do |campaign|
    logger.debug("Campaign #{campaign.id}")
    campaign.get_clusters
    test=false

    # Prologue and epilogue
    campaign.clusters.each_key do |cluster_id|
      cluster = Cigri::Cluster.new(:id => cluster_id)
      # Prologue
      if not campaign.prologue_ok?(cluster_id)
        if ( not cluster.blacklisted? and not 
                 cluster.blacklisted?(:campaign_id => campaign.id) )
          logger.debug("Prologue not executed for #{campaign.id} on #{cluster.name}")
          if not campaign.prologue_running?(cluster_id)
            logger.debug("Launching prologue for #{campaign.id} on #{cluster.name}")
            # launch the prologue job
            Cigri::Job.new({:cluster_id => cluster_id,
                     :param_id => 0,
                     :campaign_id => campaign.id,
                     :tag => "prologue",
                     :state => "to_launch",
                     :runner_options => '{"besteffort":"false"}'})
          else
            logger.debug("Prologue currently running for #{campaign.id} on #{cluster.name}")
          end # Prologue running
        else
          logger.info("Not running prologue for #{campaign.id} on #{cluster.name} because of blacklist")
        end # Cluster blacklisted
      end # Prologue not ok
      # Epilogue
      if not campaign.has_remaining_tasks? and
         not campaign.has_to_launch_jobs? and
         not campaign.has_launching_jobs? and
         not campaign.has_active_jobs? and
         not campaign.epilogue_ok?(cluster_id)
         if ( not cluster.blacklisted? and not
                 cluster.blacklisted?(:campaign_id => campaign.id) )
           logger.debug("Epilogue not executed for #{campaign.id} on #{cluster.name}")
          if not campaign.epilogue_running?(cluster_id)
            logger.debug("Launching epilogue for #{campaign.id} on #{cluster.name}")
            # launch the epilogue job
            Cigri::Job.new({:cluster_id => cluster_id,
                     :param_id => 0,
                     :campaign_id => campaign.id,
                     :tag => "epilogue",
                     :state => "to_launch",
                     :runner_options => '{"besteffort":"false"}'})
          else
            logger.debug("Epilogue currently running for #{campaign.id} on #{cluster.name}")
          end # Epilogue running
        end # Cluster blacklisted
      end

    end

    # Filling queues
    queuing=true
    while campaign.has_remaining_tasks? and campaign.have_active_clusters? and queuing do
      queuing=false
      campaign.clusters.each_key do |cluster_id|
        cluster = Cigri::Cluster.new(:id => cluster_id)
        if ( not cluster.blacklisted? and not 
                 cluster.blacklisted?(:campaign_id => campaign.id) ) 
          if cluster.queue_low?
            if not campaign.prologue_ok?(cluster_id)
              logger.debug("Not queuing cluster #{cluster.name} for campaign #{campaign.id} because of prologue") 
            else 
              logger.debug("Queuing for campaign #{campaign.id} on cluster #{cluster.name}")
              queing=true
    
              # Prepare options for scheduler call
              opts={}
              # Test mode
              if campaign.clusters[cluster.id]["test_mode"] == "true"
                test=true
                opts={
                       :max_jobs => 1,
                       :besteffort => false
                     }
              # Campaign types
              else
                case campaign.clusters[cluster.id]["type"]
                  when "best-effort"
                  opts={
                          :max_jobs => max_jobs,
                          :besteffort => true
                       }
                  when "normal"
                  opts={
                         :max_jobs => max_jobs,
                         :besteffort => false
                       }
                  else
                  logger.warn("Unknown campaign type: "+campaign.clusters[cluster.id]["type"].to_s+"; using best-effort")
                  opts={
                          :max_jobs => max_jobs,
                          :besteffort => true
                       }
                end
              end
              # Grouping
              if campaign.clusters[cluster.id]["temporal_grouping"] == "true"
                opts["temporal_grouping"] = true
              elsif campaign.clusters[cluster.id]["dimensional_grouping"] == "true"
                opts["dimensional_grouping"] = true
              end
              
              # Scheduler call
              scheduler=Cigri::SchedulerFifo.new(campaign,cluster.id,opts)
              scheduler.do

            end # Prologue nok
          end # Low queue
        else
          logger.info("Cluster #{cluster.name} is blacklisted for campaign #{campaign.id}") 
        end
        
      end
     
      # For the test mode, remove all remaining tasks
      if test
        db_connect() do |dbh|
           remove_remaining_tasks(dbh,campaign.id)
        end
      end
      sleep 2
    end
 end
  
  logger.debug('Exiting')
end
