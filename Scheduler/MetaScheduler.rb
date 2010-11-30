#!/usr/bin/ruby
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
$:.unshift(File.dirname($0))

if get_conf("DEBUG")
  $verbose=get_conf("DEBUG").to_i>=1
else
  $verbose=false
end

require 'dbi'
require 'time'
require 'optparse'
require 'yaml'
require 'pp'
require 'cigriUtils'
require 'cigriClusters'
require 'cigriJobs'
require 'cigriCampaignScheduler'


#########################################################################
# Main
#########################################################################

puts "[METASCHEDULER]   Begining of scheduler FIFO\n";

# Connect to database
dbh = db_init()

free_resources = Hash.new()

# Select all the clusters and get free nodes
clusters=get_cigri_clusters(dbh)
clusters.each do |cluster|
  free_resources[cluster.name] = cluster.free_resources - cluster.waiting_resources
  warn "#{cluster.name}: #{cluster.free_resources} - #{cluster.waiting_resources}" if $verbose
end

if $verbose
	free_resources.sort.each {|cluster, nb| 
		warn "[METASCHEDULER]  #{cluster} => #{nb} free nodes"}  
end



#ensure that test jobs are scheduled first if they exist
#mjobset = get_test_intreatment_mjobset(dbh)
#mjobset += get_default_intreatment_mjobset(dbh)
#mjobset += get_batch_intreatment_mjobset(dbh)
mjobset = get_intreatment_mjobset(dbh)
#pas de raison de s'emmerder pour l'instant

# since updator runs synchronously, keep locally n_waiting jobs 
# to avoid lauching more than needed
waiting_jb = Hash.new()
mjobset.each{|mjob| waiting_jb["#{mjob.mjobid}"]=mjob.n_waiting}


mjobset.each do |mjob| 
	mjob.active_clusters.each do |cluster|
	used_nodes = 0

	if(free_resources["#{cluster.name}"].to_i > 0 && waiting_jb["#{mjob.mjobid}"] > 0)
		if (mjob.type == "test")
			used_nodes = TestScheduler.schedule(mjob, cluster.name, free_resources["#{cluster.name}"].to_i)
		elsif (mjob.type == "batch")
			used_nodes = BatchScheduler.schedule(mjob, cluster.name, free_resources["#{cluster.name}"].to_i)			
		else
			used_nodes = DefaultScheduler.schedule(mjob, cluster.name, free_resources["#{cluster.name}"].to_i)
  	   	end

		free_resources["#{cluster.name}"] -= used_nodes
		free_resources["#{cluster.name}"] = 0 if free_resources["#{cluster.name}"].to_i < 0
		waiting_jb["#{mjob.mjobid}"] -= used_nodes
	end 
	end
end


puts "[METASCHEDULER]   End of scheduler FIFO\n";


