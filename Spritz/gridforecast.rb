#!/usr/bin/ruby -w
# 
####################################################################################
# CIGRI Forecaster.
# It is based on the job throughput (a number of jobs per time unit on a time window)
# At the beginning of the campain, as the throughput is not relevant, it is based on 
# the average duration of jobs divided by the current number of running jobs.
#
# Output: in YAML format
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
    puts "Usage: #{$0} <multiple_job_id>"
    exit 1
end

# Get the multiple job
mjob=MultipleJob.new(dbh,ARGV[0])

puts mjob if $verbose
puts "Forecast (average method): #{forecast_average(mjob)}" if $verbose
puts "Forecast (throughput method): #{forecast_throughput(mjob,$time_window_size)}" if $verbose

average=mjob.average

# Use the average forcaster at the beginning of the job
# and use the throughput forecaster after
if average[0] == 0 || mjob.duration < (2 * average[0])
    forecasted=forecast_average(mjob)
    forecaster='average'
else
    forecasted=forecast_throughput(mjob,$time_window_size)
    forecaster='throughput'
end

# Make an array with the forecast
result = { 'mjob_id' => mjob.mjobid.to_i,
           'forcaster' => forecaster,
	   'status' => mjob.status,
	   'duration' => mjob.duration
         }
if mjob.status == 'TERMINATED'
    result['end_time'] = mjob.last_terminated_date if mjob.status == 'TERMINATED'
else 
    result['end_time'] = Time.now.to_i + forecasted
end
result['data'] = { 'throughput' => sprintf("%.6f",mjob.throughput($time_window_size)).to_f,
                   'average' => sprintf("%.2f",average[0]).to_f,
                   'standard_deviation' => sprintf("%.2f",average[1]).to_f
                 }
# YAML Output
puts YAML.dump(result)
