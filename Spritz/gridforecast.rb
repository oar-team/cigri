#!/usr/bin/ruby
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
require 'cigriForecasts'

if get_conf("DEBUG")
  $verbose=get_conf("DEBUG").to_i>=1
else
  $verbose=false
end

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
warn "Getting the mjob" if $verbose
mjob=MultipleJob.new(dbh,ARGV[0])
warn "Getting the forecast" if $verbose
forecasts=Forecasts.new(mjob)

#put forecasts

warn mjob if $verbose
warn forecasts if $verbose

average=forecasts.get_global_average

$stderr.printf("Forecast (average method): %.3f\n", average[0]) if $verbose

$stderr.printf("Forecast (throughput method): %.3f\n", forecasts.get_global_throughput($time_window_size)) if $verbose

# Use the average forcaster at the beginning of the job
# and use the throughput forecaster after

if average[0] == 0 || mjob.duration < (2 * average[0])
     forecasted=forecasts.get_forecast_average
     forecaster='average'
else
     forecasted=forecasts.get_forecast_throughput($time_window_size)
     forecaster='throughput'
 end

 
# Make an array with the forecast
result = { 'mjob_id' => mjob.mjobid.to_i,
           'forcaster' => forecaster,
   	       'status' => mjob.status,
		   'duration' => mjob.duration
         }


# end_time prediction, based on forecaster
if mjob.status == 'TERMINATED'
	result['end_time'] = mjob.last_terminated_date if mjob.status == 'TERMINATED'
else 
    result['end_time'] = Time.now.to_i + forecasted
end

#get stats for each cluster
result ['throughput'] = forecasts.throughput
result ['average'] = forecasts.average
result ['stddev'] = forecasts.stddev


# # YAML Output
puts YAML.dump(result)


