#!/usr/bin/ruby -w

$LOAD_PATH.unshift("./lib")

require 'cigri'
require 'cigri-clusterlib'

begin
  config = Cigri.conf
  logger = Cigri::Logger.new("RUNNER #{ARGV[0]}", config.get('LOG_FILE'))

  if ARGV[0].nil?
    raise Cigri::Exception, "runner should be passed the name of a cluster as an argument"
  else
    cluster=Cigri::Cluster.new(:name => ARGV[0])
  end


  %w{INT TERM}.each do |signal|
    Signal.trap(signal){ 
      #cleanup!
      logger.warn('Interruption caught: exiting.')
      exit(1)
    }
  end
  
  logger.info("Starting runner on #{ARGV[0]}")
  
  #Main runner loop
  while true do
    logger.debug('New iteration')
    sleep 10
  end
end
