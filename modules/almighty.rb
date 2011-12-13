#!/usr/bin/ruby -w

$LOAD_PATH.unshift("./lib")

require 'cigri'
require 'cigri-clusterlib'

$0='cigri: almighty'

begin
  config = Cigri.conf
  logger = Cigri::Logger.new('ALMIGHTY', config.get('LOG_FILE'))

  #Childs array
  childs=[]
  runner_childs={}

  #Signal handling
  %w{INT TERM}.each do |signal|
  Signal.trap(signal){ 
    #cleanup!
    logger.warn('Interruption caught: exiting.')
    childs.each do |pid|
      logger.warn("Killing child process ##{pid}")
      Process.kill("TERM",pid)
      Process.waitpid(pid,Process::WNOHANG)
    end
    exit(1)
  }
  end

  #Child processes monitoring
  trap("CLD") {
    pid = Process.wait
    logger.error("Child pid #{pid}: terminated")
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
  }

  
  logger.info('Starting cigri')

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
  
  #Main almighty loop
  while true do
    logger.debug('New iteration')
    system("#{File.dirname(__FILE__)}/meta-scheduler.rb")
    sleep 10
  end
end
