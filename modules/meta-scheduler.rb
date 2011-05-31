#!/usr/bin/ruby -w

$LOAD_PATH.unshift("./lib")

require 'cigri'

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
  
  db_connect() do |dbh|
    pp get_running_campaigns(dbh)
  end
  
  logger.debug('Exiting')
end
