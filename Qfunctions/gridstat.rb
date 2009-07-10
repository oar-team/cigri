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
    puts "Usage: #{$0} <multiple_job_id> [-f] [--csv] [-h]"
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

opts.on( '-h', '--help', "Display #{$0} help" ) do
    puts opts
    exit
end

end

opts.parse! ARGV


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

