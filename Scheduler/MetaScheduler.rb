#!/usr/bin/ruby -w
# 
################################################################################
# CIGRI MetaScheduler
################################################################################

################################################################################
# CONFIGURATION AND INCLUDES LOADING
################################################################################
if ENV['CIGRIDIR']
  require ENV['CIGRIDIR']+'/ConfLib/conflibCigri.rb'
else
  require File.dirname($0)+'/../ConfLib/conflibCigri.rb'
end
$:.replace([get_conf("INSTALL_PATH")+"/Iolib/"] | $:)

$verbose = false

require 'dbi'
require 'time'
require 'optparse'
require 'yaml'
require 'pp'
require 'cigriUtils'
require 'cigriClusters'
require 'cigriJobs'


#########################################################################
# Main
#########################################################################

puts "[METASCHEDULER]   Begining of scheduler FIFO\n";

# Connect to database
dbh = db_init()

free_resources = Hash.new()

# Select all the clusters and get free nodes
clusters=get_cigri_clusters(dbh)
clusters.each{|cluster| free_resources[cluster.name] = cluster.free_resources}

if $verbose
	free_resources.sort.each {|cluster, nb| 
		puts "[METASCHEDULER] #{cluster} => #{nb} free nodes"}  
end


#ensure that test jobs are scheduled first if they exist
mjobset = get_test_intreatment_mjobset(dbh)
mjobset += get_default_intreatment_mjobset(dbh)



#while there still free slots, iterate on clusters and jobs
#launching jobs and reducing them from free_resources hash
#--------------------------------------------------
# while free_resources.values.inject(0) { |s,v| s += v } > 0
# clusters.each do |cluster|
#    	mjobset.each do |mjob| 
# 		if(mjob.active_clusters.include?(cluster.name))
# 			free_resources[cluster.name] -= mjob.n_waiting * mjob.job_ratio(cluster.name)
# 			free_resources[cluster.name] = 0 if free_resources[cluster.name] < 0
# 			nb_jobs_to_submit = cluster.free_resources * mjob.job_ratio(cluster.name)
# 			mjob.add_job_to_launch(cluster, nb_jobs_to_submit)
# 		end
# 	end if free_resources[cluster.name] > 0
# end
# end
#-------------------------------------------------- 


mjobset.each do |mjob| 
	mjob.active_clusters.each do |cluster|
	used_nodes = 0
	
	if(free_resources["#{cluster.name}"].to_i > 0)

		if(mjob.type.eql? "test")
			# --- Begin test Scheduler  --- #
			used_nodes = mjob.add_job_to_launch(cluster.name, 1)
			puts "[METASCHEDULER added test toLaunch MJob: #{mjob.mjobid}; cluster; #{cluster.name}; nb jobs: #{used_nodes} "
			# --- End test Scheduler  --- #
		else
			# --- Begin Campaign Scheduler ---
			nb_jobs_to_submit = free_resources["#{cluster.name}"].to_i * mjob.job_ratio(cluster.name)
			used_nodes = mjob.add_job_to_launch(cluster.name, nb_jobs_to_submit)
			puts "[METASCHEDULER added toLaunch MJob: #{mjob.mjobid}; cluster; #{cluster.name}; nb jobs: #{used_nodes} "
			# --- End Campaign Scheduler ---
		end

	end
		
		free_resources["#{cluster.name}"] = free_resources["#{cluster.name}"].to_i - used_nodes
		free_resources["#{cluster.name}"] = 0 if free_resources["#{cluster.name}"].to_i < 0
	end 
end


puts "[METASCHEDULER]   End of scheduler FIFO\n";
