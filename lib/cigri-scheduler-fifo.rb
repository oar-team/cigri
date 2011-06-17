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
       tasks=get_tasks_for_campaign(@dbh,@campaign.id,@opts[:max_jobs])
       if tasks.length > 0
         SCHEDULERFIFOLOGGER.debug("Adding tasks in cluster #{@cluster_id} queue: #{tasks.join(",")}")
         # TODO: runner_options and tag management
         runner_options=""
         tag=""
         add_jobs_to_launch(@dbh,tasks,@cluster_id,tag,runner_options)
       end
    end

  end # class SchedulerFifo


end # module Cigri
