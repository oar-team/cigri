#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-clusterlib'
require 'cigri-joblib'
require 'cigri-eventlib'
require 'cigri-colombolib'

config = Cigri.conf
logger = Cigri::Logger.new("RUNNER #{ARGV[0]}", config.get('LOG_FILE'))

if ARGV[0].nil?
  raise Cigri::Error, "runner should be passed the name of a cluster as an argument"
end

cluster = Cigri::Cluster.new(:name => ARGV[0])

$0 = "Cigri: runner #{ARGV[0]}"

# Signal traping
%w{INT TERM}.each do |signal|
  Signal.trap(signal){ 
    #cleanup!
    logger.warn('Interruption caught: exiting.')
    exit(1)
  }
end

# The "tap" variable is like a tap. It represents the number of jobs
# we can start at a time (as a oar array job)
# We close the tap (ie set tap to 0) if the cluster is not running
# our jobs, and we open it if all the jobs are running or terminated
if config.exists?('RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS') 
  tap = config.get('RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS').to_i
else
  tap = 5
end
DEFAULT_TAP = tap

if config.exists?('RUNNER_MIN_CYCLE_DURATION')
  MIN_CYCLE_DURATION = config.get('RUNNER_MIN_CYCLE_DURATION').to_i
else
  MIN_CYCLE_DURATION = 5
end
SLEEP_MORE = 10 # used as a sleep value when no job is submitted


#Main runner loop
logger.info("Starting runner on #{ARGV[0]}")
while true do
  logger.debug('New iteration')

  start_time = Time::now.to_i
  sleep_more = 0
  tap = DEFAULT_TAP


  ##########################################################################
  # Jobs control
  ##########################################################################
  # Check if there are some jobs in the transitionnal "launching" jobs
  if cluster.has_launching_jobs?
    logger.warn("There are some 'launching' jobs!")
    launching_jobs = Cigri::Jobset.new
    launching_jobs.get_launching(cluster.id)
    launching_jobs.update({:state => 'event'})
    events=Cigri::Eventset.new()
    launching_jobs.each do |job|
      events << Cigri::Event.new(:class => "job", :code => "STUCK_LAUNCHING_JOB", :cluster_id => cluster.id, :job_id => job.id, :message => "Runner #{cluster.name} found this job stuck in the launching state")
    end
    Cigri::Colombo.new(events).check_launching_jobs
  end

  # Check if the cluster is blacklisted
  if cluster.blacklisted? 
    tap=0
    logger.warn("Cluster is blacklisted") 
  else  
    # Update the jobs state and close the tap if necessary
    # TODO: we need to find a way to have a tap per campaign as a campaign
    # may have waiting jobs but another may run fluently
    current_jobs = Cigri::Jobset.new
    current_jobs.get_submitted(cluster.id)
    current_jobs.get_running(cluster.id)
    current_jobs.each do |job|
      if job.props[:remote_id].nil? || job.props[:remote_id] == ""
        job.update({'state' => 'event'})
        message="Job #{job.id} is lost, it has no remote_id!"
        Cigri::Event.new(:class => "job", :code => "GET_REMOTE_ID_ERROR", :cluster_id => cluster.id, :job_id => job.id, :message => message)
      else
        begin
          cluster_job = cluster.get_job(job.props[:remote_id].to_i, job.props[:grid_user])
          case cluster_job["state"] 
            when /Terminated/i
              job.update({'state' => 'terminated'})
            when /Error/i
              #TODO: more checks here, to create the event and trigger automatic resubmission for jobs killed
              job.update({'state' => 'event'})
            when /Running/i
              job.update({'state' => 'running'})
            when /Finishing/i
              job.update({'state' => 'running'})
            when /Waiting/i
              job.update({'state' => 'remote_waiting'})
              # close the tap
              tap = 0
            else
              # close the tap
              tap = 0
          end
        rescue => e
          job.update({'state' => 'event'})
          message="Could not get remote job #{job.id}! #{e.to_s}"
          event=Cigri::Event.new(:class => "job", :code => "GET_ERROR", :cluster_id => cluster.id, :job_id => job.id, :message => message)
          Cigri::Colombo.new(event).check_clusters
        end
      end
    end 
  end

  ##########################################################################
  # Jobs submission
  ##########################################################################
  #
  # Get the jobs to launch and submit them
  # 
  tolaunch_jobs = Cigri::JobtolaunchSet.new
  # Get the jobs in state to_launch (should only happen after a crash)
  jobs=Cigri::Jobset.new(:where => "jobs.state='to_launch' and jobs.cluster_id=#{cluster.id}")
  # Get the jobs in the bag of tasks (if no more remaining to_launch jobs to treat)
  if jobs.length == 0 and tolaunch_jobs.get_next(cluster.id, tap) > 0 # if the tap is open
    logger.info("Got #{tolaunch_jobs.length} jobs to launch")
    # Take the jobs from the b-o-t
    jobs = tolaunch_jobs.take
  end
  if jobs.length > 0
    # Submit the new jobs
    begin
      jobs.submit(cluster.id)
    rescue => e
      message = "Could not submit jobs #{jobs.ids.inspect} on #{cluster.name}: #{e}"
      jobs.each do |job|
        job.update({'state' => 'event'})
        event=Cigri::Event.new(:class => "job", :code => "SUBMIT_ERROR", :cluster_id => cluster.id, :job_id => job.id, :message => message)
        Cigri::Colombo.new(event).check
      end
      logger.warn(message)
    end
  else
    sleep_more = SLEEP_MORE
  end

  # Sleep if necessary
  cycle_duration = Time::now.to_i - start_time
  sleep MIN_CYCLE_DURATION - cycle_duration if cycle_duration < MIN_CYCLE_DURATION
  sleep sleep_more
end
