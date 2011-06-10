#!/usr/bin/ruby -w

$LOAD_PATH.unshift("./lib")

require 'cigri'
require 'cigri-joblib'

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
  
  campaigns=Cigri::Campaignset.new
  campaigns.get_running
  campaigns.each do |campaign|
    puts "Campaign #{campaign.id} :"
    campaign.get_clusters
    campaign.clusters.each_key do |cluster_id|
      puts "  Cluster #{cluster_id}"
    end
  end
  
  logger.debug('Exiting')
end
