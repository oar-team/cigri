#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-clusterlib'
require 'cigri-joblib'
require 'cigri-eventlib'
require 'cigri-colombolib'
require 'cigri-runnerlib'

config = Cigri.conf
logfile=config.get('LOG_FILE',"STDOUT")
logger = Cigri::Logger.new("RUNNER #{ARGV[0]}", logfile)

if logfile != "STDOUT" && logfile != "STDERR"
  $stdout.reopen(logfile, "a")
  $stderr.reopen(logfile, "a")
end

if ARGV[0].nil?
  raise Cigri::Error, "runner should be passed the name of a cluster as an argument"
end

cluster = Cigri::Cluster.new(:name => ARGV[0])

$0 = "cigri: runner #{ARGV[0]}"

# Signal traping
%w{INT TERM}.each do |signal|
  Signal.trap(signal){ 
    #cleanup!
    STDERR.puts('Interruption caught: exiting.')
    exit(1)
  }
end

if config.exists?('RUNNER_MIN_CYCLE_DURATION')
  MIN_CYCLE_DURATION = config.get('RUNNER_MIN_CYCLE_DURATION').to_i
else
  MIN_CYCLE_DURATION = 5
end

def notify_judas
  Process.kill("USR1",Process.ppid)
end

#Main runner loop
logger.info("Starting runner on #{ARGV[0]}")
tap_can_be_opened={}
while true do

  logger.debug('New iteration')

  # Get current jobs
  current_jobs = Cigri::Jobset.new
  current_jobs.get_submitted(cluster.id)
  current_jobs.get_running(cluster.id)
  current_jobs.to_jobs

  # init taps
  cluster.reset_taps
  (current_jobs.campaigns + cluster.running_campaigns + cluster.paused_campaigns).uniq.each do |campaign_id|
    tap=Cigri::Tap.new(:cluster_id => cluster.id, :campaign_id => campaign_id)
    if not tap_can_be_opened[tap.id]
      tap.decrease
      tap_can_be_opened[tap.id]=true
    end
    cluster.taps[campaign_id.to_i]=tap
    logger.debug("Campaign #{campaign_id} tap #{tap.props[:state]}, rate #{tap.props[:rate]}")
  end

  start_time = Time::now.to_i
  have_to_notify = false

  ##########################################################################
  # Jobs control
  ##########################################################################
  # Check if there are some jobs in the transitionnal "launching" state
  logger.debug("Jobs control")
  if cluster.has_launching_jobs?
    logger.warn("There are some jobs in the 'launching' state!")
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
    cluster.close_taps
    tap_can_be_opened={}
    logger.warn("Cluster is blacklisted") 
  # Update the jobs state and close the tap if necessary
  else  
   # Fill job cache if cluster supports it (optimization that limits the number of queries to the cluster's api)
    if cluster.props[:api_chunk_size] and cluster.props[:api_chunk_size].to_i > 0
      joblist=[]
      current_jobs.each {|j| joblist << j.props[:remote_id] if j.props[:remote_id] }
      joblist.each_slice(cluster.props[:api_chunk_size].to_i) do |chunk|
        cluster.fill_jobs_cache(:ids => chunk)
      end
    end
    # For each job, get the status
    cluster_blacklisted_because_of_exit_errors={}
    cluster_blacklisted={}
    current_jobs.each do |job|
      campaign_id=job.props[:campaign_id].to_i
      # Get cluster blacklist status (check only once to limit the number of queries)
      if cluster_blacklisted_because_of_exit_errors[campaign_id].nil?
        cluster_blacklisted_because_of_exit_errors[campaign_id]=cluster.blacklisted_because_of_exit_errors?(:campaign_id => campaign_id)   
      end
      if cluster_blacklisted[campaign_id].nil?
        cluster_blacklisted[campaign_id]=cluster.blacklisted?(:campaign_id => campaign_id)
      end
      # Check for lost jobs
      if job.props[:remote_id].nil? || job.props[:remote_id] == ""
        job.update({'state' => 'event'})
        message="Job #{job.id} is lost, it has no remote_id! This may occur when cigri is restarted. You should resubmit this job if you care about the parameters."
        Cigri::Event.new(:class => "job", :code => "RUNNER_GET_REMOTE_ID_ERROR", :cluster_id => cluster.id, :job_id => job.id, :message => message, :campaign_id => job.props[:campaign_id])
        have_to_notify = true
      # Check jobs if the cluster is not blacklisted for this campaign
      elsif not cluster_blacklisted or cluster_blacklisted_because_of_exit_errors[campaign_id]
        begin
          cluster_job = cluster.get_job(job.props[:remote_id].to_i, job.props[:grid_user])
          case cluster_job["state"] 
            when /Terminated/i
              remote_job=nil
              stop_time=nil
              if job.props[:tag] == "batch"
                 subjob_state=job.get_subjob_state(cluster,cluster_job["launching_directory"])
                 remote_job=subjob_state
                 stop_time=Time.at(subjob_state["stop_time"].to_i)
              else
                 remote_job=cluster_job
                 stop_time=Time.at(cluster_job["stop_time"].to_i)
                 if cluster_job.has_key?('exit_code')
                   job.update({'return_code' => cluster_job['exit_code'].to_i})
                 end
              end
              if (cluster_job["exit_code"].to_i) > 0
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
              blacklisting=Cigri::Colombo.new(events).check_jobs
              job.update({'stop_time' => to_sql_timestamp(Time.at(cluster_job["stop_time"].to_i))})
              # Close the tap if it results in a blacklisting
              if blacklisting
                cluster.taps[campaign_id].close
                tap_can_be_opened[cluster.taps[campaign_id].id]=false
              end
              have_to_notify = true
            when /Running/i , /Finishing/i, /Launching/i
              if job.props[:tag] == "batch"
                logger.debug("Batch subjobs control")
                subjob_state=job.get_subjob_state(cluster,cluster_job["launching_directory"])
                case subjob_state["state"]
                  when /notstarted/i
                    job.update({'state' => 'batch_waiting'})
                  when /running/i
                    start_time=Time.at(cluster_job["start_time"].to_i)
                    job.update({'state' => 'running','start_time' => to_sql_timestamp(start_time)})
                  when /finished/i
                    start_time=Time.at(cluster_job["start_time"].to_i)
                    stop_time=Time.at(cluster_job["stop_time"].to_i)
                    if subjob_state["exit_code"].to_i > 0
                      logger.info("Sub-job #{job.id} has non-null exit-status.")
                      Cigri::Colombo::analyze_remote_job_events(job,subjob_state)
                      events=Cigri::Eventset.new({ :where => "class = 'job' and cluster_id = #{cluster.id} and state='open'"})
                      Cigri::Colombo.new(events).check_jobs
                      have_to_notify = true
                      job.update({'stop_time' => to_sql_timestamp(stop_time),
                                  'return_code' => subjob_state["exit_code"]})
                    else
                      job.update({'stop_time' => to_sql_timestamp(stop_time),
                                  'start_time' => to_sql_timestamp(start_time),
                                  'state' => 'terminated'})
                    end
                end
              else
                job.update({'state' => 'running','start_time' => to_sql_timestamp(Time.at(cluster_job["start_time"].to_i))})
              end
            when /Waiting/i
              job.update({'state' => 'remote_waiting'})
              # close the tap
              cluster.taps[campaign_id].close
              tap_can_be_opened[cluster.taps[campaign_id].id]=false
            else
              # close the tap
              cluster.taps[campaign_id].close
              tap_can_be_opened[cluster.taps[campaign_id].id]=false
          end
        rescue Cigri::ClusterAPIConnectionError => e
          message="Could not get remote job #{job.id}!\n#{e.to_s} because of a connection problem to the cluster API"
          logger.warn(message)
          cluster.taps[campaign_id].close # There's a problem, so we close the tap
          tap_can_be_opened[cluster.taps[campaign_id].id]=false
        rescue Cigri::ClusterAPITimeout => e
          message="Could not get remote job #{job.id}!\n#{e.to_s} because of a timeout with the cluster API"
          logger.warn(message)
          cluster.taps[campaign_id].close # There's a problem, so we close the tap
          tap_can_be_opened[cluster.taps[campaign_id].id]=false
        rescue Cigri::ClusterAPIServerError => e
          message="Could not get remote job #{job.id}!\n#{e.to_s} because of a (temporary?) code 500 server error with the cluster API"
          logger.warn(message)
          cluster.taps[campaign_id].close # There's a problem, so we close the tap
          tap_can_be_opened[cluster.taps[campaign_id].id]=false
          event=Cigri::Event.new(:class => "job", :code => "RUNNER_GET_JOB_SERVER_ERROR", 
                                 :cluster_id => cluster.id, :job_id => job.id, 
                                 :message => message, :campaign_id => job.props[:campaign_id].to_i)
          Cigri::Colombo.new(event).check_jobs
          have_to_notify = true
        rescue => e
          message="Could not get remote job #{job.id}!\n#{e.to_s}\n#{e.backtrace.to_s}"
          logger.warn(message)
          cluster.taps[campaign_id].close # There's a problem, so we close the tap
          tap_can_be_opened[cluster.taps[campaign_id].id]=false
          event=Cigri::Event.new(:class => "job", :code => "RUNNER_GET_JOB_UNKNOWN_ERROR", 
                                 :cluster_id => cluster.id, :job_id => job.id, 
                                 :message => message, :campaign_id => job.props[:campaign_id].to_i)
          Cigri::Colombo.new(event).check_jobs
          have_to_notify = true
          break
        end
      else
        #logger.debug("Not checking job #{job.id} because of campaign blacklist")
        cluster.taps[campaign_id].close
        tap_can_be_opened[cluster.taps[campaign_id].id]=false
      end
    end 
    cluster.clean_jobs_cache

    ##########################################################################
    # Taps re-opening
    ##########################################################################
    cluster.taps.each_key do |campaign_id|
      if tap_can_be_opened[cluster.taps[campaign_id].id]
        cluster.taps[campaign_id].open
      end
    end

    ##########################################################################
    # Jobs submission
    ##########################################################################
    #
    # Get the jobs to launch and submit them
    #
    logger.debug("Jobs submissions")
    tolaunch_jobs = Cigri::JobtolaunchSet.new
    # Get the jobs in state to_launch (should only happen for prologue/epilogue or after  a crash)
    jobs=Cigri::Jobset.new(:where => "jobs.state='to_launch' and jobs.cluster_id=#{cluster.id}")
    jobs.remove_blacklisted(cluster.id)
    # Get the jobs in the bag of tasks (if no more remaining to_launch jobs to treat)
    if jobs.length == 0 and tolaunch_jobs.get_next(cluster.id, cluster.taps) > 0 # if the tap is open
      logger.info("Got #{tolaunch_jobs.length} jobs to launch")
      # Take the jobs from the b-o-t
      jobs = tolaunch_jobs.take
      # Remove jobs from blacklisted campaigns
      jobs.remove_blacklisted(cluster.id) if jobs != false
    end
    if jobs!= false and jobs.length > 0
      # Submit the new jobs
      begin
        submitted_jobs=jobs.submit2(cluster.id)
      rescue Cigri::ClusterAPIConnectionError => e
        message = "Could not submit jobs #{jobs.ids.inspect} on #{cluster.name} because of an API error. Automatically resubmitting."
        jobs.each do |job|
          job.update({'state' => 'event'})
          job.resubmit
        end
      rescue Cigri::ClusterAPITimeoutPOST => e
        message = "Timeout during jobs submit #{jobs.ids.inspect} on #{cluster.name}. You can fix and re-submit, but be aware that some jobs may be already running with no more relation to cigri."
        jobs.each do |job|
          job.update({'state' => 'event'})
          event=Cigri::Event.new(:class => "job", :code => "RUNNER_SUBMIT_TIMEOUT",
                                 :cluster_id => cluster.id, :job_id => job.id,
                                 :message => message, :campaign_id => job.props[:campaign_id])
          Cigri::Colombo.new(event).check
          Cigri::Colombo.new(event).check_jobs
          have_to_notify = true
        end
        logger.warn(message)
      rescue Cigri::ClusterAPITooLarge => e
        message = "Request too large for jobs submit #{jobs.ids.inspect} on #{cluster.name}. Your parameters string is maybe too large. Consider indexing your parameters."
        jobs.each do |job|
          job.update({'state' => 'event'})
          event=Cigri::Event.new(:class => "job", :code => "RUNNER_SUBMIT_TOO_LARGE",
                                 :cluster_id => cluster.id, :job_id => job.id,
                                 :message => message, :campaign_id => job.props[:campaign_id])
          Cigri::Colombo.new(event).check
          Cigri::Colombo.new(event).check_jobs
          have_to_notify = true
        end
        logger.warn(message)
      rescue Cigri::TokenNotFound => e
        message = "Could not submit jobs #{jobs.ids.inspect} on #{cluster.name}: Auth token is not found. Please, use the 'gridtoken' command to set up an authentication token for #{cluster.name}."
        jobs.each do |job|
          job.update({'state' => 'event'})
          event=Cigri::Event.new(:class => "job", :code => "RUNNER_SUBMIT_TOKEN_NOT_FOUND", 
                                 :cluster_id => cluster.id, :job_id => job.id, 
                                 :message => message, :campaign_id => job.props[:campaign_id])
          Cigri::Colombo.new(event).check
          Cigri::Colombo.new(event).check_jobs
          have_to_notify = true
        end
        logger.warn(message)
      rescue Cigri::ClusterAPIPermissionDenied => e
        message = "Permission denied while submitting jobs #{jobs.ids.inspect} on #{cluster.name}: check that you have a valid authorization on #{cluster.name}. Error was: #{e}"
        jobs.each do |job|
          job.update({'state' => 'event'})
          event=Cigri::Event.new(:class => "job", :code => "RUNNER_SUBMIT_PERMISSION_DENIED", 
                                 :cluster_id => cluster.id, :job_id => job.id, 
                                 :message => message, :campaign_id => job.props[:campaign_id])
          Cigri::Colombo.new(event).check
          Cigri::Colombo.new(event).check_jobs
          have_to_notify = true
        end
        logger.warn(message)
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
      sleep 3 # wait a little bit as we just submitted some jobs
      # Increase tap of the first campaign that runs well
      # (in case we submitted for several campaigns, but this should
      # not happen with the Jobset::submit2 method)
      submitted_campaigns=[]
      if submitted_jobs and submitted_jobs.length > 0
        jobs.each do |j| 
          if not submitted_campaigns.include?(j.props[:campaign_id].to_i)
            submitted_campaigns << j.props[:campaign_id].to_i
          end
         end
        submitted_campaigns.each do |campaign_id|
          if cluster.taps[campaign_id] and cluster.taps[campaign_id].open? and cluster.taps[campaign_id].props[:rate].to_i < (submitted_jobs.length*RUNNER_TAP_INCREASE_FACTOR+1)
            cluster.taps[campaign_id].increase
            break # or campaigns may evolve in parallell
          end
        end
      end
    end
  end 

  # notify
  notify_judas if have_to_notify

  # Sleep if necessary
  cycle_duration = Time::now.to_i - start_time
  sleep MIN_CYCLE_DURATION - cycle_duration if cycle_duration < MIN_CYCLE_DURATION
end
