#!/usr/bin/ruby -w
# 
####################################################################################
# CIGRI queue stat fonction
#
# Requirements:
#        ruby1.8 (or greater)
#        libdbi-ruby
#        libdbd-mysql-ruby or libdbd-pg-ruby
#        libyaml-ruby
# ###################################################################################

##################################################################################
# CONFIGURATION AND INCLUDES LOADING
##################################################################################
if ENV['CIGRIDIR']
  require ENV['CIGRIDIR']+'/ConfLib/conflibCigri.rb'
else
  require File.dirname($0)+'/../ConfLib/conflibCigri.rb'
end
$:.replace([get_conf("INSTALL_PATH")+"/Iolib/"] | $:)

require 'dbi'
require 'time'
require 'optparse'
require 'yaml'
require 'pp'
require 'cigriJobs'
require 'cigriUtils'
require 'cigriForecasts'

$verbose = false
#$verbose = true

if get_conf("TIME_WINDOW_SIZE")
  $time_window_size=get_conf("TIME_WINDOW_SIZE").to_i
else
  $time_window_size=3600
end

#########################################################################
# MAIN
#########################################################################

# Connect to database
dbh = db_init()

# Check args
if ARGV.empty?
    puts "Usage: #{$0} <multiple_job_id> [-f ID | -s RANGE] [--csv] [-h]"
    exit 1
end

#cParse args
options = {}

opts = OptionParser.new do|opts|

options[:full] = false
opts.on( '-f', '--full', 'Show full information about campaigns' ) do
  options[:full] = true
end

options[:csv] = false
opts.on( '--csv', 'Print information in csv format' ) do
  options[:csv] = true
end

options[:summary] = false
opts.on( '-s', '--summary ID or RANGE', 'Print summary information' ) do |range| 
  options[:summary] = range
end

opts.on( '-h', '--help', "Display #{$0} help" ) do
    puts opts
    exit
end

end

opts.parse! ARGV


if !options[:summary]
	# Get the multiple job
	mjob=MultipleJob.new(dbh,ARGV[0])
	forecasts=Forecasts.new(mjob)

	if not options[:csv]
	  puts mjob.to_s
	  puts
  
	  if options[:full]
		puts forecasts.to_s_full
		puts
	  	puts "List of jobs:"
  

	  	mjob.jobs.each do |job|
    		printf("Job %s: %s\n  Cluster: %s\n  Node: %s\n  BatchId: %s\n  Params: %s\n",
        		job.jid,job.state,job.cluster,job.node,job.batchid,job.param)
		end
	  else
    	 	puts forecasts.to_s
	  end

	else
	  puts "\"id\",\"state\",\"cluster\",\"node\",\"batchid\",\"params\""
	  mjob.jobs.each do |job|
	    printf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n",
    	    job.jid,job.state,job.cluster,job.node,job.batchid,job.param)
	  end
	end
else
	# matches: 
	#    *-* : All the mjobs
	#    n-* : All the mjobs starting in 'n'
	#    *-n : All the mjobs from 0 to 'n'
	#    n-m : All the mjobs from between 'n' and 'm' included
	#    n   : just the mjob 'n' 
	if (options[:summary] =~ /^\s*(\d+|\*)\s*(-\s*(\d+|\*)\s*)?$/ ) == nil
		puts "ERROR #{options[:summary]} is not a valid range"
		puts opts
		exit(-1)
	end

	if  (!$1.eql? "*") && (!$3.eql? "*") && $1!=nil && $3!=nil && $1.to_i >= $3.to_i
		puts "ERROR #{options[:summary]} is not a valid range. Second number must be bigger than first in the range"
		puts opts
		exit(-1)
	end

	

	($1.eql? "*") ? begin_id=0 : begin_id=$1.to_i
	($3.eql? "*") ? end_id=get_last_mjobid(dbh) : end_id=$3.to_i
	end_id = -1 if end_id == 0
	#puts "checking from #{begin_id} to #{end_id}"

	mjobset = get_mjobset_range(dbh, begin_id, end_id)


	puts("Campaign Id  Status       Type       Waiting  Running  Finished  Error to Fix")
	puts("-----------  ------------ ---------  -------  -------  --------  ------------ ")
	mjobset.each do |mjob|
		 j=MultipleJob.new(dbh,mjob.mjobid)
		 if (j.has_errors_to_fix)
		 	 puts sprintf("   %-9.9s %-13.13s %-10.10s   %-7.7s  %-9.9s %-10.10s %s\n", j.mjobid, j.status, j.type, j.n_waiting, j.n_running, j.n_terminated, "x");
		 else
		 	 puts sprintf("   %-9.9s %-13.13s %-10.10s   %-7.7s  %-9.9s %-8.8s\n", j.mjobid, j.status, j.type, j.n_waiting, j.n_running, j.n_terminated);
		 end
	end
	puts("-----------  ------------ ---------  -------  -------  --------  ------------ ")


end

