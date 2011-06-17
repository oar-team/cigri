#!/usr/bin/ruby -w

$LOAD_PATH.unshift("./lib")

require 'cigri'
require 'cigri-clusterlib'
require 'cigri-joblib'

begin
  config = Cigri.conf
  logger = Cigri::Logger.new("RUNNER #{ARGV[0]}", config.get('LOG_FILE'))

  if ARGV[0].nil?
    raise Cigri::Exception, "runner should be passed the name of a cluster as an argument"
  else
    cluster=Cigri::Cluster.new(:name => ARGV[0])
  end

  # Signal traping
  %w{INT TERM}.each do |signal|
    Signal.trap(signal){ 
      #cleanup!
      logger.warn('Interruption caught: exiting.')
      exit(1)
    }
  end
  

  # Default configuration
  if config.exists?('') 
    n=config.get('RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS')
  else
    n=5
  end
 
  #Main runner loop
  logger.info("Starting runner on #{ARGV[0]}")
  while true do
    logger.debug('New iteration')

    ##########################################################################
    # Jobs checking
    ##########################################################################
    # TODO

    ##########################################################################
    # Jobs submission
    ##########################################################################
    #
    # Get the jobs to launch
    # 
    tolaunch_jobs=Cigri::JobtolaunchSet.new
    if tolaunch_jobs.get_next(cluster.id,n) > 0
      logger.debug("Got #{tolaunch_jobs.length} jobs to launch")
      tolaunch_jobs.remove
              # Remove the jobs from the queue
      tolaunch_jobs.register
              # Create the new jobs
              # Submit the new jobs
    end
    sleep 10
  end
end
