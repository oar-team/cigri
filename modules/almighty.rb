#!/usr/bin/ruby -w
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-clusterlib'
require 'cigri-colombolib'

$0='cigri: almighty'

sleeptime=10
child_timeout=60

begin
  config = Cigri.conf
  logfile=config.get('LOG_FILE',"STDOUT")
  logger = Cigri::Logger.new('ALMIGHTY', logfile)

  if logfile != "STDOUT" && logfile != "STDERR"
    $stdout.reopen(logfile, "a")
    $stderr.reopen(logfile, "a")
  end

  #Childs array
  childs=[]
  runner_childs={}
  judas_pid=nil

  #Signal handling
  %w{INT TERM}.each do |signal|
  Signal.trap(signal){ 
    #cleanup!
    logger.warn('Interruption caught: exiting.')
    # Reset trap on childs
    trap("CHLD") {
      # do nothing
    }
    # Kill every child
    childs.each do |pid|
      logger.warn("Killing child process ##{pid}")
      Process.kill("TERM",pid)
      Process.waitpid(pid,Process::WNOHANG)
    end
    exit(1)
  }
  end

  #Forward SIGUSR1 to Judas (check notifications) 
  trap("USR1") {
    logger.debug("Received USR1, forwarding to Judas.")
    Process.kill("USR1",judas_pid)
  }

  #Child processes monitoring
  trap("CHLD") {
    pid, status = Process.wait2
    logger.error("Child pid #{pid}: terminated with status #{status.exitstatus}") if status != 0
    childs.delete(pid)
    if not runner_childs[pid].nil?
      Cigri::Event.new(:class => "log", :code => "RUNNER_FAILED", :state => "closed", :message => "Runner of #{runner_childs[pid]} terminated! Restarting.")
      sleep 5
      logger.warn("Restarting runner for #{runner_childs[pid]}")
      npid=fork
      if npid.nil?
        exec("#{File.dirname(__FILE__)}/runner.rb", runner_childs[pid])
      else
        childs << npid
        runner_childs[npid]=runner_childs[pid]
        runner_childs.delete(pid)
      end
    end
    if pid == judas_pid
      Cigri::Event.new(:class => "log", :code => "JUDAS_FAILED", :state => "closed", :message => "Judas terminated! Restarting.")
      sleep 5
      logger.warn("Restarting judas")
      npid=fork
      if npid.nil?
        exec("#{File.dirname(__FILE__)}/judas.rb")
      else
        childs << npid
        judas_pid = npid
      end
    end
  }

  
  logger.info('Starting cigri')

  #Do an initial check of events
  Cigri::Colombo.new().check
  Cigri::Colombo.new().check_jobs

  # Make some initial checks of the database
  Cigri::Colombo::check_database

  #Start the runners
  clusters=Cigri::ClusterSet.new
  if clusters.length <= 0
    logger.error('No cluster into database! Please add some clusters! Exiting.')
    exit(2)
  end
  clusters.each do |cluster|
    logger.debug("Starting runner for #{cluster.name}")
    pid=fork
    if pid.nil?
      exec("#{File.dirname(__FILE__)}/runner.rb", cluster.name)
    else
      childs << pid
      runner_childs[pid]=cluster.name
    end
    sleep 0.5
  end
 
  # Start the notification module (judas)
  logger.debug("Starting judas")
  pid=fork
  if pid.nil?
    exec("#{File.dirname(__FILE__)}/judas.rb")
  else
    childs << pid
    judas_pid = pid
  end

  # Load the modules
  cigri_modules={
         'metascheduler' => "#{File.dirname(__FILE__)}/meta-scheduler.rb",
         'updator' => "#{File.dirname(__FILE__)}/updator.rb",
         'nikita' => "#{File.dirname(__FILE__)}/nikita.rb",
  }

  #Main almighty loop executing modules sequentially
  while true do
    logger.debug('New iteration')
    t=Time.now
    ["metascheduler","updator","nikita"].each do |mod|
      pid=fork { exec(cigri_modules[mod]) }
      logger.debug("Spawned #{mod} process #{pid}")
      # Here, we cannot make a simple Process.waitpid as it seems to conflict
      # Furthermore, we check like this so we can set up a timeout recovery.
      wait=true
      count=0
      while wait and count < child_timeout
        begin
          Process.kill(0,pid)
          sleep 1
          logger.debug("Waiting for #{mod}... #{count}")
          count+=1
        rescue
          wait=false
        end
      end
      if wait==true
        Cigri::Event.new(:class => "log", :code => "CHILD_TIMEOUT", :state => "closed", :message => "#{mod} timeout! Canceling!")
        logger.error("#{mod} timeout! Canceling!")
        Process.kill("TERM",pid) 
      end
      logger.debug("#{mod} process terminated")
    end
    # Sleep if necessary
    duration=Time.now - t
    if duration < sleeptime
      sleep sleeptime - duration
    end
  end
end
