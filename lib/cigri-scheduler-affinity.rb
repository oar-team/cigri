#!/usr/bin/ruby -w
#
# This library contains the cigri affinity scheduler
# This scheduler takes into account priorities defined into
# tasks_affinity.
# A Cigri scheduler takes on input an ordered list of 
# cluster,campaign to schedule (computed by the meta-scheduler)
# It generates jobs_to_launch entries.

require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-iolib'

CONF=Cigri.conf unless defined? CONF
SCHEDULERLOGGER = Cigri::Logger.new('SCHEDULER-AFFINITY', CONF.get('LOG_FILE'))

module Cigri

  class SchedulerAffinity
 
    def initialize(campaigns,cluster_campaigns)
      @campaigns=campaigns
      @cluster_campaigns=cluster_campaigns
      # Hash for storing tasks orders
      @stacks={}
      # Cluster queues
      @queues={}
      @dbh=db_connect()
    end
   
    # Take the next task for given cluster from the stacks 
    def pop_campaign(cluster_id)
      task=nil
      cur_campaign=nil
      @stacks[cluster_id].each do |campaign_id,campaign|
      # TODO: Maybe we should check here if the queue has its
      # max_jobs, and then empty the corresponding stack 
        if campaign.length > 0
          task=[campaign.pop,campaign_id]
          cur_campaign=campaign_id
          break
        end
      end
      # Now, remove the popped task from other clusters
      if not task.nil?
        @stacks.each_key do |cluster_id|
          @stacks[cluster_id][cur_campaign].delete(task[0])
        end
        return task
      else
        return nil
      end
    end

    # Compute the tasks to put into queues for each (cluster,campaign) pair
    # Make a set of stacks from which we will pop the jobs.
    # The stacks may contain the same tasks, but in different orders. This is
    # different from the queues as this structure is only used for sorting.
    # Also get current state of each campaign to know how many jobs to queue
    def compute_stacks(max_tasks)
      max={}
      @cluster_campaigns.each do |pair|
        cluster_id=pair[0]
        campaign_id=pair[1]
        SCHEDULERLOGGER.debug{"Scheduling campaign #{campaign_id} on cluster #{cluster_id}"}
        campaign=@campaigns.get_campaign(campaign_id)
        # Potential tasks, ordered
        if @stacks[cluster_id].nil?
          @stacks[cluster_id]={}
        end
        @stacks[cluster_id][campaign_id]=@campaigns.compute_tasks_list(cluster_id,campaign_id,max_tasks).reverse
      end     
    end

    # Construct a queue per cluster.
    # A cluster queue is an ordered list of [task_id,campaign_id] pair
    # (The campaign_id is a quick reminder to prevent useless quering
    # of the database)
    # Here, we pop tasks from the stacks, one by one, to distribute them
    # on the clusters in the right order
    # TODO: should take into account the max_jobs to queue (third element
    # from the metascheduler).
    def setup_queues
      not_finished=true
      while not_finished
        not_finished=false
        @stacks.each_key do |cluster_id|
          if @queues[cluster_id].nil?
            @queues[cluster_id]=[]
          end
          task=pop_campaign(cluster_id)
          if task
            not_finished=true
            @queues[cluster_id] << task
          end
        end
      end
    end

    # Batch the tasks by campaigns
    # This last step takes care of grouping and passing runner options
    def batch_tasks
      @queues.each do |cluster_id,tasks|
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
            campaign=@campaigns.get_campaign(campaign_id)
            # Construct options depending on campaign types
            opts = campaign.get_runner_options(cluster_id)
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
            SCHEDULERLOGGER.debug("Queing #{batch['tasks'].length} jobs for cluster #{cluster_id}")
            add_jobs_to_launch(dbh,batch["tasks"],cluster_id,batch["tag"],batch["opts"])
          end
        end
        puts "#{cluster_id}: #{batches.inspect}"
      end
    end

    def do
      compute_stacks(20)
      setup_queues
      batch_tasks
    end

  end # class SchedulerAffinity


end # module Cigri
