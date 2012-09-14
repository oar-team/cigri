#!/usr/bin/ruby -w
#
# This library contains the cigri fifo scheduler
#

require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-iolib'

CONF=Cigri.conf unless defined? CONF
SCHEDULERFIFOLOGGER = Cigri::Logger.new('SCHEDULER-FIFO', CONF.get('LOG_FILE'))

module Cigri

  class SchedulerFifo
 
    def initialize(campaign,cluster_id,opts={})
      @campaign=campaign
      @cluster_id=cluster_id
      @opts=opts
      @dbh=db_connect()
    end
    
    def do
       tasks=get_tasks_ids_for_campaign(@dbh,@campaign.id,@opts[:max_jobs])
       @opts.delete(:max_jobs)
       if not tasks.nil? and tasks.length > 0
         SCHEDULERFIFOLOGGER.debug("Adding tasks in cluster #{@cluster_id} queue: #{tasks.join(",")}")
         # The tag is something that may be passed by the meta-scheduler ("prologue" or "epilogue"
         # for example)
         tag=''
         if @opts[:tag]
           tag=@opts[:tag]
           @opts.delete(:tag)
         end
         # Put the jobs into the runner queue. All options except tag and max_jobs are
         # passed to the runner.
         add_jobs_to_launch(@dbh,tasks,@cluster_id,tag,@opts)
       end
    end

  end # class SchedulerFifo


end # module Cigri
