# CiGri Campaign Scheduler definitions

##########################################################
# MJob Test Scheduler
##########################################################
class TestScheduler
	def self.schedule(mjob, cluster_name, free_resources)
		used_nodes = 0
		used_nodes = mjob.add_job_to_launch(cluster_name, 1)
        puts "[TEST_SCHEDULER] added toLaunch MJob: #{mjob.mjobid}; cluster; #{cluster_name}; nb jobs: #{used_nodes} "
		return used_nodes
	end
end

##########################################################
# MJob Default Scheduler
##########################################################
class DefaultScheduler
	def self.schedule(mjob, cluster_name, free_resources)
		nb_jobs_to_submit = free_resources * mjob.job_ratio(cluster_name)
        used_nodes = mjob.add_job_to_launch(cluster_name, nb_jobs_to_submit)
		puts "[DEFAULT_SCHEDULER added toLaunch MJob: #{mjob.mjobid}; cluster; #{cluster_name}; nb jobs: #{used_nodes} "
		return used_nodes
	end
end




