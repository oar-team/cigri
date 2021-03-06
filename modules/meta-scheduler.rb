#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-joblib'
require 'cigri-iolib'
require 'cigri-scheduler-affinity'
require 'cigri-eventlib'

$0='cigri: metascheduler'

begin

  config = Cigri.conf
  logfile=config.get('LOG_FILE',"STDOUT")
  logger = Cigri::Logger.new('META-SCHEDULER', logfile)

  if logfile != "STDOUT" && logfile != "STDERR"
    $stdout.reopen(logfile, "a")
    $stderr.reopen(logfile, "a")
  end
  
  %w{INT TERM}.each do |signal|
    Signal.trap(signal){ 
      #cleanup!
      STDERR.puts('Interruption caught: exiting.')
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
      if not campaign.prologue_ok?(cluster_id) and campaign.has_remaining_tasks?
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

  # Reset the queues
  #db_connect do |dbh|
  #  reset_cluster_queues(dbh)
  #end

  # Pass the ordered list to the scheduler
  scheduler=Cigri::SchedulerAffinity.new(campaigns,cluster_campaigns) 
  scheduler.do
  scheduler.disconnect
 
  # End 
  logger.debug('Exiting')

end


