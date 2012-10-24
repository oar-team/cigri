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
  logger = Cigri::Logger.new('UPDATOR', config.get('LOG_FILE'))
 
  GRID_USAGE_UPDATE_PERIOD=config.get('GRID_USAGE_UPDATE_PERIOD',60)
 
  %w{INT TERM}.each do |signal|
    Signal.trap(signal){ 
      #cleanup!
      logger.warn('Interruption caught: exiting.')
      exit(1)
    }
  end
  
  logger.debug('Starting')

  # Check for finished campaigns
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
                       :code => "FINISHED_CAMPAIGN", :message => "Campaign is finished")
      notify_judas
    end
  end 

  # Autofix clusters
  events=Cigri::Eventset.new({:where => "state='open' and class='cluster'"})
  Cigri::Colombo.new(events).autofix_clusters

  # Check for blacklists
  events=Cigri::Eventset.new({:where => "state='open' and code='BLACKLIST'"})
  Cigri::Colombo.new(events).check_blacklists

  # Check jobs to resubmit
  events=Cigri::Eventset.new({:where => "state='open' and code='RESUBMIT' and class='job'"})
  Cigri::Colombo.new(events).check_jobs

  # Update grid_usage table
  #TODO: test if it is the time to do this using GRID_USAGE_UPDATE_PERIOD
  begin
    Cigri::ClusterSet.new.each do |cluster|
      resources=cluster.get_resources
      # Count the resource_units
      resource_units=resources.map{|r| r[cluster.props[:resource_unit]]}.uniq
      # Match jobs and resources
      #TODO
      jobs=cluster.get_jobs
      # Create the entry
      date=Time.now
      Datarecord.new("grid_usage",{:date => date,
                                 :cluster_id => cluster.id,
                                 :max_resources => resource_units.length
                                })
    end 
  rescue => e
    logger.warn("Could not update the grid_usage table! #{e.message} #{e.backtrace}") 
  end

  logger.debug('Exiting')
end
