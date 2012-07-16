#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-joblib'

$0='cigri: updator'

begin
  config = Cigri.conf
  logger = Cigri::Logger.new('UPDATOR', config.get('LOG_FILE'))
  
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
    if campaign.finished?
      campaign.update({'state' => 'terminated'})
      logger.info("Campaign #{campaign.id} is finished")
    end
  end  
  
  logger.debug('Exiting')
end
