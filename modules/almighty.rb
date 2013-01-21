#!/usr/bin/ruby -w
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-clusterlib'
require 'cigri-colombolib'

$0='cigri: almighty'

begin
  config = Cigri.conf
  logger = Cigri::Logger.new('ALMIGHTY', config.get('LOG_FILE'))

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
         'metascheduler' => "#{File.dirname(__FILE__)}/meta-scheduler2.rb",
         'updator' => "#{File.dirname(__FILE__)}/updator.rb",
         'nikita' => "#{File.dirname(__FILE__)}/nikita.rb",
  }

  #Main almighty loop executing modules sequentially
  while true do
    logger.debug('New iteration')
    ["metascheduler","updator","nikita"].each do |mod|
      pid=fork { exec(cigri_modules[mod]) }
      logger.debug("Spawned #{mod} process #{pid}")
      # Here, we cannot make a simple Process.waitpid as it seems to conflict
      # with the traps defined earlier. So, we loop on a WNOHANG wait to
      # check if the process is ended or not.
      wait=true
      while wait
        begin
          Process.waitpid(pid,Process::WNOHANG)
          sleep 1
        rescue
          wait=false
        end
      end
      #logger.debug("#{mod} process terminated")
    end
    sleep 10
  end
end
