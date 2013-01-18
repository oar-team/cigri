#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-joblib'
require 'cigri-iolib'
require 'cigri-scheduler-affinity'
require 'cigri-eventlib'

$0='cigri: metascheduler'


# Initiate a global hash for storing ordered lists of tasks
$stacks={}
# Global hash to hold the number of jobs queued for a given campain
# on a given cluster ($n[pair] with pair=[cluster_id,campaign_id])
$n={}

# Take a task from the stacks, in the right order, for a cluster
def pop_campaign(cluster_id)
  task=nil
  campaign=nil
  $stacks[cluster_id].each do |campaign_id,campaign|
    if campaign.length > 0
      task=[campaign.pop,campaign_id]
      campaign=campaign_id
      break
    end
  end
  # Now, remove the popped task from other clusters
  if not task.nil?
    $stacks.each_key do |cluster_id|
      $stacks[cluster_id][campaign].delete(task[0])
    end
    return task
  else
    return nil
  end
end

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

  # Get the running campaigns
  campaigns=Cigri::Campaignset.new
  campaigns.get_running
  
  # Check for and start prologue/epilogue if necessary 
  logger.debug('Checking pro/epilogue')
  campaigns.each do |campaign|
    campaign.get_clusters

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
  end #End of loop on campaigns for pro/epilogue

  # Compute the ordered list of (cluster,campaigns) pairs
  # This does a first filtering on blacklists, prologue and stress_factor
  # Order is given by users_priority.
  logger.debug('Campaigns sorting')
  cluster_campaigns=campaigns.compute_campaigns_orders

  # Start the scheduler
  scheduler=Cigri::SchedulerAffinity.new(campaigns,cluster_campaigns) 
  scheduler.do
 
  # End 
  logger.debug('Exiting')

end


