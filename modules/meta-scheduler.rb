#!/usr/bin/ruby -w

$LOAD_PATH.unshift("./lib")

require 'cigri'
require 'cigri-joblib'
require 'cigri-scheduler-fifo'

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
    while campaign.have_remaining_tasks? and campaign.have_active_clusters? do
      campaign.clusters.each_key do |cluster_id|
        logger.debug("Queuing for campaign #{campaign.id} on cluster #{cluster_id}")

        # As an example, we check the campaign_type:
        if campaign.clusters[cluster_id]["campaign_type"] != "best-effort"
          logger.warn("Only best-effort campaigns are supported for now!")
        end

        # Scheduler call
        scheduler=Cigri::SchedulerFifo.new(campaign,cluster_id,{
                                                            :max_jobs => max_jobs,
                                                            :best_effort => true
                                                            })
        scheduler.do

      end
    sleep 2
    end
  end
  
  logger.debug('Exiting')
end
