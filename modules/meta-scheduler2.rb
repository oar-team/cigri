#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-joblib'
require 'cigri-iolib'
require 'cigri-scheduler-fifo'
require 'cigri-eventlib'

$0='cigri: metascheduler'


# Initiate a global variable for storing ordered lists of tasks
$stacks={}

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

  # Compute the tasks to put into queues for each (cluster,campaign) pair
  # Make a set of stacks from which we will pop the jobs.
  # Also get current state of each campaign to know how many jobs to queue
  max={}
  cluster_campaigns.each do |pair|
    cluster_id=pair[0]
    campaign_id=pair[1]
    logger.debug{"Scheduling campaign #{campaign_id} on cluster #{cluster_id}"}
    campaign=campaigns.get_campaign(campaign_id)
    # Potential tasks, ordered
    if $stacks[cluster_id].nil?
      $stacks[cluster_id]={}
    end
    $stacks[cluster_id][campaign_id]=campaigns.compute_tasks_list(cluster_id,campaign_id,20).reverse
    # Number of currently running tasks
 #   running_tasks=campaign.get_number_running_on_cluster(cluster_id)
    # Currently queued tasks
 #   queued_tasks=campaign.get_number_queued_on_cluster(cluster_id)   
    # Max to queue
 #   max[pair]=#TODO
  end
 
  # Schedule jobs (construct a queue per cluster)
  # A cluster queue is an ordered list of [task_id,campaign_id] pair
  # (The campaign_id is a quick reminder to prevent useless quering
  # of the database)
  # This step is not exactly scheduling as it is really done earlier 
  # by the compute_tasks_list method. But it manages with the number
  # of jobs that should be in queues (especially the max_jobs and test_mode
  # options)
  queues={}
  not_finished=true
  while not_finished
    not_finished=false
    $stacks.each_key do |cluster_id|
      #TODO: manage sums, max_jobs and test_mode
      if queues[cluster_id].nil?
        queues[cluster_id]=[]
      end
      task=pop_campaign(cluster_id)
      if task
        not_finished=true
        queues[cluster_id] << task
      end
    end
  end

  # Batch the tasks by campaigns
  # This last step takes care of grouping and passing runner options
  #
  queues.each do |cluster_id,tasks|
    batches=[]
    batch=nil
    campaign_id=nil
    campaign=nil
    tasks.each do |task_array|
      task=task_array[0]
      # New batch
      if task_array[1] != campaign_id
        # The current batch is finished, add it to the list of batches
        batches << batch if batch
        # Get campaign properties
        campaign_id=task_array[1]
        campaign=campaigns.get_campaign(campaign_id)
        # Construct options depending on campaign types
        #TODO
        opts = { :besteffort => 1 } # just for testing
        # Initiate the new batch
        batch={ "tasks" => [], "tag" => nil, "opts" => opts }
      end
      # Add the task into the current batch
      batch["tasks"] << task    
    end
    # Put the last batch into the list of batches
    batches << batch if batch

    # Actual queuing!
    db_connect() do |dbh|
      batches.each do |batch|
        logger.debug("Queing #{batch['tasks'].length} jobs for cluster #{cluster_id}")
        add_jobs_to_launch(dbh,batch["tasks"],cluster_id,batch["tag"],batch["opts"])
      end
    end 
    puts "#{cluster_id}: #{batches.inspect}"
  end
 
 
=begin

    test=false
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

=end
  
  logger.debug('Exiting')

end


