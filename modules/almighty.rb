#!/usr/bin/ruby -w

$LOAD_PATH.unshift("./lib")

require 'cigri'

begin
  config = Cigri.conf
  logger = Cigri::Logger.new('ALMIGHTY', config.get('LOG_FILE'))

  %w{INT TERM}.each do |signal|
  Signal.trap(signal){ 
    #cleanup!
    logger.warn('Interruption caught: exiting.')
    exit(1)
  }
  end
  
  logger.info('Starting cigri')
  
  #Main almighty loop
  while true do
    logger.debug('New iteration')
    sleep 10
  end
end
