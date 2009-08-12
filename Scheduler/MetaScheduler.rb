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
$:.unshift(File.dirname($0))


$verbose = false

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
clusters.each{|cluster| free_resources[cluster.name] = cluster.free_resources}

if $verbose
	free_resources.sort.each {|cluster, nb| 
		puts "[METASCHEDULER] #{cluster} => #{nb} free nodes"}  
end


#ensure that test jobs are scheduled first if they exist
mjobset = get_test_intreatment_mjobset(dbh)
mjobset += get_default_intreatment_mjobset(dbh)


mjobset.each do |mjob| 
	mjob.active_clusters.each do |cluster|
	used_nodes = 0
	
	if(free_resources["#{cluster.name}"].to_i > 0)
		case (mjob.type)
		  when "test" : used_nodes = TestScheduler.schedule(mjob, cluster.name, free_resources["#{cluster.name}"].to_i)
		  when "default" : used_nodes = DefaultScheduler.schedule(mjob, cluster.name, free_resources["#{cluster.name}"].to_i)
  	   end

		free_resources["#{cluster.name}"] = free_resources["#{cluster.name}"].to_i - used_nodes
		free_resources["#{cluster.name}"] = 0 if free_resources["#{cluster.name}"].to_i < 0
	end 
	end
end


puts "[METASCHEDULER]   End of scheduler FIFO\n";
