# CiGri Campaign Scheduler definitions

# Configuration loading
if ENV['CIGRIDIR']
  require ENV['CIGRIDIR']+'/ConfLib/conflibCigri.rb'
else
  require File.dirname($0)+'/../ConfLib/conflibCigri.rb'
end
$:.replace([get_conf("INSTALL_PATH")+"/Iolib/"] | $:)
$:.unshift(File.dirname($0))

if get_conf("MAX_JOBS")
  $max_jobs=get_conf("MAX_JOBS").to_i
else
  $max_jobs=1000
end


##########################################################
# MJob Test Scheduler
##########################################################
class TestScheduler
	def self.schedule(mjob, cluster_name, free_resources)
		#ensure one job / cluster
		return 0 if mjob.deployed_clusters.include? cluster_name
		used_nodes = 0
		used_nodes = mjob.add_job_to_launch(cluster_name, 1)
        	puts "[TEST_SCHEDULER] added toLaunch MJob: #{mjob.mjobid}; cluster; #{cluster_name}; nb jobs: #{used_nodes} " if used_nodes > 0
		mjob.notify_deployed_cluster(cluster_name) if used_nodes > 0
		return used_nodes
	end
end

##########################################################
# MJob Default Scheduler
##########################################################
class DefaultScheduler
	def self.schedule(mjob, cluster_name, free_resources)
		nb_jobs_to_submit = free_resources * mjob.job_ratio(cluster_name)
		nb_jobs_to_submit = $max_jobs if nb_jobs_to_submit.to_i > $max_jobs
	        used_nodes = mjob.add_job_to_launch(cluster_name, nb_jobs_to_submit)
		puts "[DEFAULT_SCHEDULER added toLaunch MJob: #{mjob.mjobid}; cluster; #{cluster_name}; nb jobs: #{used_nodes} " if used_nodes > 0
		return used_nodes
	end
end




