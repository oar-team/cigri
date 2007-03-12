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

#####################################################################################
#
# CONFIGURATION
#
#####################################################################################

# You can store the configuration on a separate file or comment out the configuration
# variables below
load "/etc/gridforecast.conf"

# Database configuration
#$cigri_db = 'cigri'
#$host = 'localhost'
#$login = 'root'
#$passwd = ''

# Size of the window in seconds on wich the job throughput is calculated
# time_window_size = 3600

# Verbosity (for debuging purpose)
$verbose = false
#$verbose = true

#######################################################################################

require 'dbi'
require 'time'
require 'optparse'
require 'yaml'
require 'pp'

#########################################################################
# Job class
#########################################################################
class Job
    attr_reader :mjobid, :state, :tsub, :tstart, :tstop

    # Creation
    def initialize(id,mjobid,state,tsub,tstart,tstop)
        @id=id
        @mjobid=mjobid
        @state=state
        @tsub=tsub
        @tstart=tstart
        @tstop=tstop
    end

    # Printing
    def to_s
        puts "Job #{id}:#{state},#{tsub},#{tstart},#{tstop}"
    end

    # Calculate the job duration (from submission to end or now)
    def duration
        if state == 'Terminated'
            return tstop - tsub
        else
            return Time.now.to_i - tsub
        end
     end
end

#########################################################################
# MultipleJob class
#########################################################################
class MultipleJob
    attr_reader :mjobid, :jobs, :last_terminated_date, :status, :n_running, :n_terminated

    # Creation
    # Yes, this constructor is a bit big, but it is for optimum performance
    #  (not too much sql requests or array parsing)
    def initialize(dbh,id)
        @dbh=dbh
        @mjobid=id
        @jobs=[]
        @durations=[]
        @last_terminated_date=0
        @first_submited_date=0
        @n_running=0
        @n_terminated=0
        @n_trans=0

        # Status of this multiple job
        query = "SELECT MJobsState, MJobsTSub FROM multipleJobs where MJobsId=#{mjobid}"
        sql_mjob=dbh.select_all(query)
	if sql_mjob.empty?
	    raise "Could not find multiplejob #{mjobid}"
	end
        @status=sql_mjob[0]['MJobsState']
        @tsub=to_unix_time(sql_mjob[0]['MJobsTSub'])

        # SQL query to get the jobs
        query = "SELECT jobId, jobMJobsId, jobState, jobTSub, jobTStart, jobTStop \
                 FROM jobs \
                 WHERE jobMJobsId=#{mjobid}"
        sql_jobs=dbh.select_all(query)

        # Job objects creation and parsing
        sql_jobs.each do |sql_job|
            job=Job.new(sql_job['jobId'],\
                        id,\
                        sql_job['jobState'],\
                        to_unix_time(sql_job['jobTSub']),\
                        to_unix_time(sql_job['jobTStart']),\
                        to_unix_time(sql_job['jobTStop']))
            @jobs << job

            case job.state
                when  'Terminated'
                    # Get the date of the last terminated job and the number of terminated jobs
                    @last_terminated_date = job.tstop if @last_terminated_date < job.tstop
                    @n_terminated+=1

                    # Make an array of jobs durations
                    @durations << job.duration

                when 'Running'
                    # Get the number of running jobs
                    @n_running+=1
                when 'toLaunch', 'RemoteWaiting'
                    # Get the number of jobs in a transitional status
                    @n_trans+=1
            end

            # Get the date of the first submited job
            @first_submited_date = job.tsub if @first_submited_date > job.tsub
        end
    end

    # Number of waiting parameters
    def n_waiting
        query = "SELECT count(*) as n FROM parameters WHERE parametersMJobsId=#{@mjobid}"
        return @dbh.select_all(query)[0]['n'].to_i + @n_trans
    end

    # Duration of this multiple job
    def duration
        return Time.now.to_i - @tsub if @status != 'TERMINATED'
        return @last_terminated_date - @tsub else 
    end

    # Job throughput during the time window
    def throughput(time_window_size)
        return @n_terminated.to_f/duration.to_f if @status == 'TERMINATED'
        n=0
        first_submited_date = Time.now.to_i
        jobs.each do |job|
            if job.state == 'Terminated' && job.tsub > (Time.now - time_window_size).to_i
                n+=1
                first_submited_date = job.tsub if job.tsub < first_submited_date
            end
        end
        if n != 0
            return n.to_f / (Time.now.to_i - first_submited_date).to_f
        else
            return 0.0
        end
    end

    # Mean and stddev duration of terminated jobs
    def average
        if !@durations.empty?
            std_dev = @durations.first **2
            total = @durations.inject {|sum, d| std_dev += d * d; sum + d }
            n = @durations.length.to_f
            mean = total.to_f / n
            std_dev = Math.sqrt(std_dev.to_f / n - mean **2)
            return [mean,std_dev]
        else
            return [0.0,0.0]
        end
    end

    # Printing
    def to_s
        sprintf("Multiple job %i 
        Status:                 %s
        Submited:               %s
        Last terminated job:    %s 
        Running:                %i 
        Waiting:                %i 
        Terminated:             %i 
        Troughput (last hour):  %i jobs/hour 
        Duration:               %i s 
        Average:                %i s 
        Stddev:                 %.2f", \
        @id,@status,Time.at(@tsub),Time.at(@last_terminated_date),@n_running,n_waiting,@n_terminated,\
	throughput(3600)*3600.to_i,duration,average[0].to_i,average[1])
    end
end

#########################################################################
# Functions
#########################################################################

# Convert a MySQL date into a unix timestamp
#
def to_unix_time(time)
    if time.nil?
      return 0
    else
      year, month, day, hour, minute, sec = time.to_s.split(/ |:|-/)
      unix_sec = Time.local(year, month, day, hour, minute, sec).to_i
      return unix_sec
    end
end

# Convert a time into number of seconds
#
def hmstos(hms)
    h,m,s = hms.to_s.split(/:/)
    return 3600*h.to_i + 60*m.to_i + s.to_i
end

# Convert a number of seconds into a duration in days, hours and minutes
#
def stodhm(s)
    d = s/(24*3600)
    s -= d * (24*3600)
    h = s / 3600
    m = (s- h * 3600) / 60
    return "#{d} days #{h}:#{m}"
end

# Connect to the database
#
def base_connect(dbname_host,login,passwd)
    return DBI.connect("dbi:Mysql:#{dbname_host}",login,passwd)
end

# Make a forecast based on the average job duration and number 
# of currently running jobs. Returns a number of seconds
def forecast_average(mjob)
    if mjob.n_running != 0 
        return ( ((mjob.n_waiting + mjob.n_running/2) * mjob.average[0]) / mjob.n_running ).to_i
    else
        return 0
    end
end

# Make a forecast based on the job throughput in the last window seconds
# Returns a number of seconds
def forecast_throughput(mjob,window)
    if mjob.throughput(window) != 0
        return ( (mjob.n_waiting + mjob.n_running/2) / mjob.throughput(window) ).to_i
    else
        return 0
    end
end

#########################################################################
# MAIN
#########################################################################

# Connect to database
dbh = base_connect("#{$cigri_db}:#{$host}",$login,$passwd)

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
result['data'] = { 'throughput' => sprintf("%.2f",mjob.throughput($time_window_size)).to_f,
                   'average' => sprintf("%.2f",average[0]).to_f,
                   'standard_deviation' => sprintf("%.2f",average[1]).to_f
                 }
# YAML Output
puts YAML.dump(result)
