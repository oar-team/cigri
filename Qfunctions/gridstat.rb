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
    puts "Usage: #{$0} <multiple_job_id> [-csv]"
    exit 1
end

if ARGV[1] == '-csv'
    csv=1
end

# Get the multiple job
mjob=MultipleJob.new(dbh,ARGV[0])

if not csv
  puts mjob.to_s
  puts "List of jobs:"
  puts

  mjob.jobs.each do |job|
    printf("Job %s: %s\n  Cluster: %s\n  Node: %s\n  BatchId: %s\n  Params: %s\n",
        job.jid,job.state,job.cluster,job.node,job.batchid,job.param)
  end
else
  puts "\"id\",\"state\",\"cluster\",\"node\",\"batchid\",\"params\""
  mjob.jobs.each do |job|
    printf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n",
        job.jid,job.state,job.cluster,job.node,job.batchid,job.param)
  end
end
