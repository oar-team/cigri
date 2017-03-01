#!/usr/bin/ruby -w
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-clusterlib'
require 'cigri-colombolib'

$0='cigri: almighty'

File.open("/var/run/cigri/almighty.pid", "w") do |f|
  f.write $$
end

sleeptime=10
child_timeout=300

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
    STDERR.puts('Interruption caught: exiting.')
    Cigri::Event.new(:class => "log", :code => "ALMIGHTY_TERMINATING", :state => "closed", :message => "Cigri is terminating!")
    Process.kill("USR1",judas_pid)
    sleep(3)
    # Reset trap on childs
    trap("CHLD") {
      # do nothing
    }
    # Kill every child
    childs.each do |pid|
      STDERR.puts("Killing child process ##{pid}")
      Process.kill("TERM",pid)
      Process.waitpid(pid,Process::WNOHANG)
    end
    exit(1)
  }
  end

  #Forward SIGUSR1 to Judas (check notifications) 
  trap("USR1") {
    STDERR.puts("Received USR1, forwarding to Judas.")
    Process.kill("USR1",judas_pid)
  }

  #Catch STOP
  trap("STOP") {
    #Do nothing
  }

  #Child processes monitoring
  trap("CHLD") {
    pid, status = Process.waitpid2(-1,Process::WNOHANG)
    if status != 0
      STDERR.puts("Child pid #{pid}: terminated with status #{status.inspect}")
    else
      STDERR.puts("Child pid #{pid}: CHLD received with status 0")
    end
    childs.delete(pid)
    if not runner_childs[pid].nil?
      Cigri::Event.new(:class => "log", :code => "RUNNER_FAILED", :state => "closed", :message => "Runner of #{runner_childs[pid]} terminated! Restarting.")
      Process.kill("USR1",judas_pid)
      sleep 5
      STDERR.puts("Restarting runner for #{runner_childs[pid]}")
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
      STDERR.puts("Restarting judas")
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


  Cigri::Event.new(:class => "log", :code => "ALMIGHTY_STARTING", :state => "closed", :message => "Cigri is starting.")
  sleep(3)
  Process.kill("USR1",judas_pid)

  #Main almighty loop executing modules sequentially
  while true do
    logger.debug('New iteration')
    t=Time.now
    ["metascheduler","updator","nikita"].each do |mod|
      modpid=spawn(cigri_modules[mod])
      logger.debug("Spawned #{mod} process #{modpid}")
      wait=true
      count=0
      while wait and count < child_timeout
        begin
          Process.getpgid( modpid )
          count+=1
          #logger.debug("Waiting for #{mod} process to terminate...#{count}")
          sleep 1
        rescue Errno::ESRCH
          logger.debug("#{mod} process terminated")
          wait=false
        end
      end
      if wait==true
        Cigri::Event.new(:class => "log", :code => "CHILD_TIMEOUT", :state => "closed", :message => "#{mod} timeout! Canceling!")
        Process.kill("USR1",judas_pid)
        logger.error("#{mod} timeout! Canceling!")
        begin
          Process.kill("TERM",modpid) 
        rescue
          # Do nothing
        end
      end
    end
    # Sleep if necessary
    duration=Time.now - t
    if duration < sleeptime
      sleep sleeptime - duration
    end
  end

end

