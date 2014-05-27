#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-joblib'
require 'cigri-colombolib'
require 'cigri-clusterlib'
require 'cigri-iolib'

$0='cigri: updator'

def notify_judas
  Process.kill("USR1",Process.ppid)
end

begin
  config = Cigri.conf
  logfile=config.get('LOG_FILE',"STDOUT")
  logger = Cigri::Logger.new('UPDATOR', logfile)

  if logfile != "STDOUT" && logfile != "STDERR"
    $stdout.reopen(logfile, "a")
    $stderr.reopen(logfile, "a")
  end
 
  GRID_USAGE_UPDATE_PERIOD=config.get('GRID_USAGE_UPDATE_PERIOD',60).to_i
  GRID_USAGE_SYNC_TIME=config.get('GRID_USAGE_SYNC_TIME',10).to_i
 
  %w{INT TERM}.each do |signal|
    Signal.trap(signal){ 
      #cleanup!
      logger.warn('Interruption caught: exiting.')
      exit(1)
    }
  end
  
  logger.debug('Starting')

  ## 
  # Check for finished campaigns
  ## 
  campaigns=Cigri::Campaignset.new
  campaigns.get_running
  campaigns.each do |campaign|
    logger.debug("campaign #{campaign.id} has remaining tasks") if campaign.has_remaining_tasks?
    logger.debug("campaign #{campaign.id} has to_launch jobs") if campaign.has_to_launch_jobs?
    logger.debug("campaign #{campaign.id} has launching jobs") if campaign.has_launching_jobs?
    logger.debug("campaign #{campaign.id} has active jobs") if campaign.has_active_jobs?
    logger.info("campaign #{campaign.id} has open events") if campaign.has_open_events?
    if campaign.finished?
      campaign.update({'state' => 'terminated'})
      logger.info("Campaign #{campaign.id} is finished")
      Cigri::Event.new(:class => 'notify', :state => 'closed', :campaign_id => campaign.id,
                       :code => "FINISHED_CAMPAIGN", :message => "Campaign #{campaign.id} is finished")
      notify_judas
    end
    if config.get("LOG_LEVEL")=="DEBUG"
      stats=campaign.average_job_duration
      logger.debug("campaign #{campaign.id} avg: #{stats[0]} stddev: #{stats[1]}")
    end
  end 

  ## 
  # Autofix clusters
  ## 
  events=Cigri::Eventset.new({:where => "state='open' and class='cluster'"})
  Cigri::Colombo.new(events).autofix_clusters

  ## 
  # Check for blacklists
  ## 
  events=Cigri::Eventset.new({:where => "state='open' and code='BLACKLIST'"})
  Cigri::Colombo.new(events).check_blacklists

  ## 
  # Check jobs to resubmit
  ##
  # !!!!
  # Commented because it can cause a job to be resubmited twice as the runners do the same!
  # !!!!
  #events=Cigri::Eventset.new({:where => "state='open' and code='RESUBMIT' and class='job'"})
  #Cigri::Colombo.new(events).check_jobs

  ## 
  # Update grid_usage table
  ## 
  last_grid_usage_entry_date=0
  sync_seconds=GRID_USAGE_SYNC_TIME # Max seconds to wait for synchro of the updator processes
  db_connect do |dbh|
    last_grid_usage_entry_date=last_grid_usage_entry_date(dbh)
  end
  if Time.now.to_i - last_grid_usage_entry_date.to_i > GRID_USAGE_UPDATE_PERIOD
   logger.debug("updating grid_usage")
    begin
      cigri_jobs=Cigri::Jobset.new
      cigri_jobs.get_running
      cigri_jobs.records.map! {|j| j.props[:remote_id].to_i }        
      date=Time.now
      Cigri::ClusterSet.new.each do |cluster|
        if not cluster.blacklisted?
          pid=fork
          if pid.nil?
            sync_date=Time.now.to_i
            # Get the resource_units
            logger.debug("Getting resources of #{cluster.name} (it takes at least #{sync_seconds} seconds)")
            cluster_resources=cluster.get_resources
            cigri_resources=0
            unavailable_resources=[]
            resource_units={}
            cluster_resources.each do |r|
              resource_units[r["id"]]=r[cluster.props[:resource_unit]]
              if r["state"] != "Alive" and
                 (r["state"] != "Absent" or (r["state"] == "Absent" and r["available_upto"].to_i < Time.now.to_i))
                unavailable_resources << r[cluster.props[:resource_unit]]
              end
            end
            max_resource_units=resource_units.values.uniq.length 
    
            # Get the cluster jobs
            cluster_jobs=cluster.get_jobs
            # Jobs consume resources units
            #TODO: remove jobs running on suspected resources!
            cluster_jobs.each do |cluster_job|
              cluster_job["resources"].each do |job_resource|
                count=resource_units.length
                resource_units.delete_if {|k,v| v==resource_units[job_resource["id"]] }
                if cigri_jobs.records.include?(cluster_job["id"].to_i )
                  cigri_resources+=count-resource_units.length
                end
              end
            end
              
            # Dirty synchro to maximize the chances of having the new sql entries at the same time
            seconds=Time.now.to_i-sync_date
            if seconds < sync_seconds
              sleep sync_seconds - seconds
            end
   
            # Create the entry
            Datarecord.new("grid_usage",{:date => date,
                                       :cluster_id => cluster.id,
                                       :max_resources => max_resource_units,
                                       :used_resources => max_resource_units - resource_units.values.uniq.length,
                                       :used_by_cigri => cigri_resources,
                                       :unavailable_resources => unavailable_resources.uniq.length
                                      })
            exit(0)
          end
        end 
      end
      Process.waitall
    rescue => e
      logger.warn("Could not update the grid_usage table! #{e.message} #{e.backtrace}") 
    end
  end
 
  ## 
  # Update clusters stress factors
  ## 
  logger.debug("updating stress_factors")
  have_to_notify=false
  Cigri::ClusterSet.new.each do |cluster|
    if not cluster.blacklisted?
      stress_factor=cluster.get_global_stress_factor
      if stress_factor != cluster.props[:stress_factor]
        # update stress factor value
        c=Datarecord.new("clusters",:id => cluster.id)
        c.update!({"stress_factor" => stress_factor})
        # log an event if now under stress (and wasn't before)
        if stress_factor >= STRESS_FACTOR
          e=Cigri::Eventset.new(:where => "cluster_id = #{cluster.id} and code='UNDER_STRESS' and state='open'")
          if not e.records[0]
            Cigri::Event.new(:class => 'cluster', :state => 'open', :cluster_id => cluster.id,
                         :code => "UNDER_STRESS", :message => "Cluster #{cluster.name} is under stress (#{stress_factor}/#{STRESS_FACTOR})!")
            have_to_notify=true
          end
        end
        # close event if no more under stress
        logger.debug("Stress factor for #{cluster.name}: #{stress_factor}/#{STRESS_FACTOR}")
        if stress_factor < STRESS_FACTOR
          e=Cigri::Eventset.new(:where => "cluster_id = #{cluster.id} and code='UNDER_STRESS' and state='open'")
          e.records[0].close if e.records[0]
        end
      end
    end
  end
  notify_judas if have_to_notify 
 
  logger.debug('Exiting')
end
