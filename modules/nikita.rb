#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-iolib'
require 'cigri-joblib'
require 'cigri-eventlib'
require 'cigri-colombolib'

$0='cigri: nikita'

def notify_judas
  Process.kill("USR1",Process.ppid)
end

begin
  config = Cigri.conf
  logfile = config.get('LOG_FILE',"STDOUT")
  $logger = Cigri::Logger.new('NIKITA', logfile)

  if logfile != "STDOUT" && logfile != "STDERR"
    $stdout.reopen(logfile, "a")
    $stderr.reopen(logfile, "a")
  end
  
  %w{INT TERM}.each do |signal|
    Signal.trap(signal){ 
      #cleanup!
      STDERR.puts('Interruption caught: exiting.')
      exit(1)
    }
  end
  
  # Kill function
  def kill(job,event)
      state=job.props[:state]

      # Kill running or waiting jobs
      if state == "running" or state == "remote_waiting" or state == "batch_waiting"
        $logger.debug("Killing job #{job.id}")
        job_event=Cigri::Event.new({:class => "job", 
                          :job_id => job.id, 
                          :code => event.props[:code],
                          :state => "closed",
                          :message => "Nikita requested to kill the job because of a #{event.props[:code]} event"})
        job.update({:state => "event"})
        job_event.close
        begin
          j=job.kill
          return j
        rescue => e
          $logger.warn("Kill function could not kill job #{job.id}")
          $logger.debug("Error while killing #{job.id}: #{e}")
          return false
        end

      # Remove to_launch jobs
      elsif state == "to_launch"
        job.delete
        return 1

      # Do nothing for launching jobs, but warn as we must wait
      elsif state == "launching"
        $logger.warn("The job #{job.id} is in the launching state. We have to wait.")
        return false
      end
  end

  $logger.debug('Starting')

  jobs_killed={}

  # Clean the affinity table every hour
  events=Cigri::Eventset.new({:where => "class='log' and code='NIKITA_CLEAN_AFFINITY' and now() - date_open < interval '1 hour'"})
  if events.empty?
    $logger.debug('Cleaning the tasks_affinity table')
    db_connect do |dbh|
      clean_tasks_affinity_table(dbh)
    end
    Cigri::Event.new(:class => 'log', :state => 'closed', 
                     :code => "NIKITA_CLEAN_AFFINITY", 
                     :message => "Nikita cleaned affinity table")
  end

  # Refresh the Dataset class connexion handler
  events.disconnect

  # Check for campaigns to kill
  $logger.debug('Check for campaigns to kill')
  events=Cigri::Eventset.new({:where => "class='campaign' and code='USER_FRAG' and state='open'"})
  events.each do |event|
    can_close=true

    # Treat the jobs that have open events (close them)
    $logger.debug("   Closing jobs with events (campaign #{event.props[:campaign_id]})")
    job_events=Cigri::Eventset.new({:where => "class='job' and campaign_id=#{event.props[:campaign_id]} and state='open'"})
    job_events.update({:state => 'closed'}) if job_events.length > 0

    # Treat the other jobs
    $logger.debug("   Killing jobs of campaign #{event.props[:campaign_id]}")
    jobs=Cigri::Jobset.new({:where => "jobs.campaign_id=#{event.props[:campaign_id]} and jobs.state != 'event' and jobs.state != 'terminated'"})
    jobs.each do |job|
      cluster_id=job.props[:cluster_id].to_s
      if jobs_killed.key?(cluster_id) and job.props.key?(:remote_id)
        if jobs_killed[cluster_id].include?(job.props[:remote_id].to_i)
          $logger.debug("Job #{job.id} already killed. Doing nothing.")
        end
      else
        r=kill(job,event)
        if r
          if jobs_killed.key?(cluster_id)
            jobs_killed[cluster_id] << r.to_i
          else
            jobs_killed[cluster_id] = [r.to_i]
          end
        else
          $logger.warn("Could not kill job #{job.id}!")
          Cigri::Event.new(:class => 'notify', :state => 'closed',
                         :code => "NIKITA_KILL_PROBLEM", :message => "Nikita could not kill job #{job.id}!")
          notify_judas
          can_close=false
        end
      end
    end
    if can_close
      event.close
    end
  end

  # Check for unitary jobs to kill
  $logger.debug('Check for unitary jobs to kill')
  events=Cigri::Eventset.new({:where => "class='job' and code='USER_FRAG' and state='open'"})
  events.each do |event|
    job_events=Cigri::Eventset.new({:where => "class='job' and job_id=#{event.props[:job_id]} and state='open' and not code='USER_FRAG'"})
    job_events.update({:state => 'closed'}) if job_events.length > 0
    jobs=Cigri::Jobset.new(:where => "jobs.id=#{event.props[:job_id]}")
    r=kill(jobs.records[0],event)
    event.close if r
  end
  
  # Check for expired walltime
  $logger.debug('Check for expired walltime')
  have_to_notify=false
  jobs=Cigri::Jobset.new
  jobs.get_expired
  jobs.to_jobs
  Cigri::ClusterSet.new.each do |cluster|
    jobs.remove_blacklisted(cluster.id)
  end
  jobs.each do |job|
    $logger.debug("Killing job #{job.id} because of walltime")
    Cigri::Event.new({:class => "notify",
                          :job_id => job.id,
                          :campaign_id => job.props[:campaign_id],
                          :code => "CIGRI_WALLTIME",
                          :state => "closed",
                          :message => "Cigri sent kill signal to job #{job.id} because it has reached the walltime and OAR doesn't seem to care"})
    have_to_notify=true
    begin
      job.kill
      job.decrease_affinity
    rescue => e
      $logger.warn("Could not kill job #{job.id}")
      $logger.debug("Error while killing #{job.id}: #{e}")
    end
  end
  notify_judas if have_to_notify
  
  # Check for jobs in remotewaiting for too long
  $logger.debug('Check for jobs in remotewaiting for too long')
  remote_waiting_timeout=config.get("REMOTE_WAITING_TIMEOUT",900)
  jobs=Cigri::Jobset.new({:where => "jobs.state='remote_waiting' and extract('epoch' from now()) - extract('epoch' from jobs.submission_time) > #{remote_waiting_timeout}"})
  jobs.each do |job|
    job_event=Cigri::Event.new({:class => "job",
                    :job_id => job.id,
                    :code => "REMOTE_WAITING_FRAG",
                    :campaign_id => job.props[:campaign_id],
                    :state => "closed",
                    :message => "Killed because it was remote_waiting for too long. Job will be resubmitted."})
    job_event.close
    begin
      job.kill
      # Decrease affinity so that the job may be tried on another cluster
      if not job.props[:tag] == "prologue" and not job.props[:tag] == "epilogue"
        job.decrease_affinity
      end
    rescue => e
      $logger.warn("Could not kill job #{job.id}")
      $logger.debug("Error while killing #{job.id}: #{e}")
    end
  end

  # Check for queued jobs for too long
  $logger.debug('Check for queued jobs for too long')
  remote_waiting_timeout=config.get("REMOTE_WAITING_TIMEOUT",900)
  jobs=Cigri::JobtolaunchSet.new({:where => "extract('epoch' from now()) - extract('epoch' from queuing_date) > #{remote_waiting_timeout}",
                                  :what => "jobs_to_launch.id as id,jobs_to_launch.task_id as task_id,cluster_id"
                                 })
  if jobs.length > 0
    event=Cigri::Event.new({:class => "log",
                            :code => "QUEUED_FOR_TOO_LONG",
                            :state => "closed",
                            :message => "Removing #{jobs.length} jobs from the queue because they were queued for too long"})
    # Update task affinity
    jobs.each do |job|
      job.decrease_affinity
    end
    # Remove jobs from the queue
    jobs.delete!("jobs_to_launch")
    event.close
  end


  $logger.debug('Exiting')
end


