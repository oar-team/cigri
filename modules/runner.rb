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

if config.exists?('RUNNER_MIN_CYCLE_DURATION')
  MIN_CYCLE_DURATION = config.get('RUNNER_MIN_CYCLE_DURATION').to_i
else
  MIN_CYCLE_DURATION = 5
end

RUNNER_TAP_INCREASE_FACTOR = config.get('RUNNER_TAP_INCREASE_FACTOR',1.5).to_f
RUNNER_TAP_INCREASE_MAX = config.get('RUNNER_TAP_INCREASE_MAX',100).to_f

def notify_judas
  Process.kill("USR1",Process.ppid)
end

# The "tap" variable is like a tap. It represents the number of jobs
# we can start at a time (as a oar array job)
# We close the tap (ie set tap to 0) if the cluster is not running
# our jobs, and we open it if all the jobs are running or terminated
# There's a tap per campaign (represented into a hash with campaign_id 
# as the key)
DEFAULT_TAP = config.get('RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS',5).to_i
cluster.reset_taps

#Main runner loop
logger.info("Starting runner on #{ARGV[0]}")
while true do

  logger.debug('New iteration')

  # reset taps that have been closed
  cluster.running_campaigns.each do |campaign_id|
    cluster.set_tap(campaign_id,DEFAULT_TAP) if cluster.taps[campaign_id] == 0
  end

  start_time = Time::now.to_i
  sleep_more = 0
  have_to_notify = false

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
    cluster.reset_taps(0)
    logger.warn("Cluster is blacklisted") 
    sleep_more = SLEEP_MORE
  else  
    # Update the jobs state and close the tap if necessary
    current_jobs = Cigri::Jobset.new
    current_jobs.get_submitted(cluster.id)
    current_jobs.get_running(cluster.id)
    current_jobs.to_jobs
    current_jobs.each do |job|
      if job.props[:remote_id].nil? || job.props[:remote_id] == ""
        job.update({'state' => 'event'})
        message="Job #{job.id} is lost, it has no remote_id!"
        Cigri::Event.new(:class => "job", :code => "RUNNER_GET_REMOTE_ID_ERROR", :cluster_id => cluster.id, :job_id => job.id, :message => message)
        have_to_notify = true
      elsif not cluster.blacklisted?(:campaign_id => job.props[:campaign_id].to_i) or
                cluster.blacklisted_because_of_exit_errors?(:campaign_id => job.props[:campaign_id].to_i)
        begin
          cluster_job = cluster.get_job(job.props[:remote_id].to_i, job.props[:grid_user])
          case cluster_job["state"] 
            when /Terminated/i
              remote_job=nil
              stop_time=nil
              if job.props[:tag] == "batch"
                 subjob_state=job.get_subjob_state(cluster)
                 remote_job=subjob_state
                 stop_time=subjob_state["stop_time"]
              else
                 remote_job=cluster_job
                 stop_time=Time.at(cluster_job["stop_time"].to_i)
              end
              if (cluster_job["exit_code"].to_i >> 8) > 0
                logger.info("Job #{job.id} has non-null exit-status.")
                Cigri::Colombo::analyze_remote_job_events(job,remote_job)
                events=Cigri::Eventset.new({ :where => "class = 'job' and cluster_id = #{cluster.id} and state='open'"})
                Cigri::Colombo.new(events).check_jobs
                have_to_notify = true
              else
                job.update({'state' => 'terminated','stop_time' => to_sql_timestamp(stop_time)})
              end
            when /Error/i
              logger.info("Job #{job.id} is in Error state.")
              Cigri::Colombo::analyze_remote_job_events(job,cluster_job)
              events=Cigri::Eventset.new({ :where => "class = 'job' and cluster_id = #{cluster.id} and state='open'"})
              Cigri::Colombo.new(events).check_jobs
              job.update({'stop_time' => to_sql_timestamp(Time.at(cluster_job["stop_time"].to_i))})
              have_to_notify = true
            when /Running/i , /Finishing/i, /Launching/i
              if job.props[:tag] == "batch"
                subjob_state=job.get_subjob_state(cluster)
                case subjob_state[:state]
                  when /notstarted/i
                    job.update({'state' => 'batch_waiting'})
                  when /running/i
                    job.update({'state' => 'running','start_time' => subjob_state[:start_time]})
                  when /finished/i
                    if subjob_state[:exit_code] > 0
                      logger.info("Sub-job #{job.id} has non-null exit-status.")
                      Cigri::Colombo::analyze_remote_job_events(job,subjob_state)
                      events=Cigri::Eventset.new({ :where => "class = 'job' and cluster_id = #{cluster.id} and state='open'"})
                      Cigri::Colombo.new(events).check_jobs
                      have_to_notify = true
                      job.update({'stop_time' => batch_state[:stop_time]})
                    else
                      job.update({'stop_time' => batch_state[:stop_time],
                                  'start_time' => batch_state[:start_time],
                                  'state' => 'terminated'})
                    end
                end
              else
                job.update({'state' => 'running','start_time' => to_sql_timestamp(Time.at(cluster_job["start_time"].to_i))})
              end
            when /Waiting/i
              job.update({'state' => 'remote_waiting'})
              # close the tap
              cluster.set_tap(job.props[:campaign_id].to_i,0)
            else
              # close the tap
              cluster.set_tap(job.props[:campaign_id].to_i,0)
          end
        rescue Cigri::ClusterAPIConnectionError => e
          message="Could not get remote job #{job.id}!\n#{e.to_s} because of a connexion problem to the cluster API"
          logger.warn(message)
          cluster.set_tap(job.props[:campaign_id].to_i,0) # There's a problem, so we close the tap
        rescue => e
          message="Could not get remote job #{job.id}!\n#{e.to_s}\n#{e.backtrace.to_s}"
          logger.warn(message)
          cluster.set_tap(job.props[:campaign_id].to_i,0) # There's a problem, so we close the tap
          event=Cigri::Event.new(:class => "job", :code => "RUNNER_GET_JOB_ERROR", 
                                 :cluster_id => cluster.id, :job_id => job.id, 
                                 :message => message, :campaign_id => job.props[:campaign_id].to_i)

          Cigri::Colombo.new(event).check_jobs
          have_to_notify = true
          break
        end
      else
        logger.debug("Not checking job #{job.id} because of campaign blacklist")
      end
    end 

    ##########################################################################
    # Increase taps for campaigns running well
    ##########################################################################
    cluster.taps.each_key do |campaign_id|
      if cluster.taps[campaign_id] != 0 and cluster.taps[campaign_id] < RUNNER_TAP_INCREASE_MAX
          cluster.set_tap(campaign_id,(cluster.taps[campaign_id]*RUNNER_TAP_INCREASE_FACTOR).to_i)
      end
    end

    ##########################################################################
    # Jobs submission
    ##########################################################################
    #
    # Get the jobs to launch and submit them
    #

    tolaunch_jobs = Cigri::JobtolaunchSet.new
    # Get the jobs in state to_launch (should only happen for prologue/epilogue or after  a crash)
    jobs=Cigri::Jobset.new(:where => "jobs.state='to_launch' and jobs.cluster_id=#{cluster.id}")
    # Get the jobs in the bag of tasks (if no more remaining to_launch jobs to treat)
    if jobs.length == 0 and tolaunch_jobs.get_next(cluster.id, cluster.taps) > 0 # if the tap is open
      logger.info("Got #{tolaunch_jobs.length} jobs to launch")
      # Take the jobs from the b-o-t
      jobs = tolaunch_jobs.take
    end
    if jobs.length > 0
      # Submit the new jobs
      begin
        submitted_jobs=jobs.submit2(cluster.id)
        sleep_more = SLEEP_MORE if submitted_jobs.length < 1
      rescue Cigri::ClusterAPIConnectionError => e
        message = "Could not submit jobs #{jobs.ids.inspect} on #{cluster.name} because of an API error. Automatically resubmitting."
        jobs.each do |job|
          job.update({'state' => 'event'})
          job.resubmit
        end
      rescue => e
        message = "Could not submit jobs #{jobs.ids.inspect} on #{cluster.name}: #{e}\n#{e.backtrace}"
        jobs.each do |job|
          job.update({'state' => 'event'})
          event=Cigri::Event.new(:class => "job", :code => "RUNNER_SUBMIT_ERROR", 
                                 :cluster_id => cluster.id, :job_id => job.id, 
                                 :message => message, :campaign_id => job.props[:campaign_id])
          Cigri::Colombo.new(event).check
          Cigri::Colombo.new(event).check_jobs
          have_to_notify = true
        end
        logger.warn(message)
      end
    end
  end 

  # notify
  notify_judas if have_to_notify

  # Sleep if necessary
  cycle_duration = Time::now.to_i - start_time
  sleep MIN_CYCLE_DURATION - cycle_duration if cycle_duration < MIN_CYCLE_DURATION
  sleep sleep_more
end
