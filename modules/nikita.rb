#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-joblib'
require 'cigri-eventlib'

$0='cigri: nikita'

begin
  config = Cigri.conf
  logger = Cigri::Logger.new('NIKITA', config.get('LOG_FILE'))
  
  %w{INT TERM}.each do |signal|
    Signal.trap(signal){ 
      #cleanup!
      logger.warn('Interruption caught: exiting.')
      exit(1)
    }
  end
  
  logger.debug('Starting')

  # Check for campaigns to kill
  events=Cigri::Eventset.new({:where => "class='campaign' and code='USER_KILL'"})
  events.each do |event|
    can_close=true
    jobs=Cigri::Jobset.new({:where => "campaign_id=#{event.props[:campaign_id]}"})
    jobs.each do |job|
      state=job.props[:state]
      if state == "running" or state == "remote_waiting"
        logger.debug("Killing job #{job.id}")
        # TODO: Kill the job and set it to event
      elsif state == "to_launch"
        # TODO: remove the job
      elsif state == "launching"
        # TODO: log a message
        can_close=false
      elsif state == "event"
        # TODO: hum, what can we do?
      end
    end
    if can_close
      event.close
    end
  end

  logger.debug('Exiting')
end
