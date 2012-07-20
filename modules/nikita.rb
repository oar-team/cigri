#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-joblib'
require 'cigri-eventlib'
require 'cigri-colombolib'

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
  events=Cigri::Eventset.new({:where => "class='campaign' and code='USER_FRAG'"})
  events.each do |event|
    can_close=true

    # Treat the jobs that have open events (close them)
    job_events=Cigri::Eventset.new({:where => "class='job' and campaign_id=#{event.props[:campaign_id]} and state='open'"})
    job_events.update({:state => 'closed'}) if job_events.length > 0

    # Treat the other jobs
    jobs=Cigri::Jobset.new({:where => "jobs.campaign_id=#{event.props[:campaign_id]} and jobs.state != 'event'"})
    jobs.each do |job|
      state=job.props[:state]

      # Kill running or waiting jobs
      if state == "running" or state == "remote_waiting"
        logger.debug("Killing job #{job.id}")
        job_event=Cigri::Event.new({:class => "job", 
                          :job_id => job.id, 
                          :code => "USER_FRAG",
                          :message => "Nikita requested to kill the job because of a USER_FRAG event on campaign #{event.props[:campaign_id]}"})
        job.update({:state => "event"})
        job_event.close
        begin
          job.kill
        rescue => e
          logger.warn("Could not kill job #{job.id}")
          logger.debug("Error while killing #{job.id}: #{e}")
        end

      # Remove to_launch jobs
      elsif state == "to_launch"
        job.delete

      # Do nothing for launching jobs, but warn as we must wait
      elsif state == "launching"
        logger.warn("The job #{job.id} is in the launching state. We have to wait.")
        can_close=false
      end
    end
    if can_close
      event.close
    end
  end

  # Check for unitary jobs to kill
  # TODO

  # Check for jobs in remotewaiting for too long
  # TODO


  logger.debug('Exiting')
end
