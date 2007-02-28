#!/usr/bin/ruby -w
#
# gridforecast is a simple multiple_job termination time forecasting tool for cigri middleware
# 
# forcasting use an extrapolation based on jobs terminated average  
#
#####################################################
# 
# USAGE
#
#####################################################
#
# gridforecast [multiple_job_id]
#
# output: in YAML format
#
# example:
# :mjob_id: 11 
# :status: ok
# :data: 
#  :average: "18.19"
#  :standard_deviation: "12.66"
# :forcaster: average
# :duration: 0
# :end_time: 1168353337

# status forcaster duration_to_completion time_to_completion [complementary_forecasters_information] 
#  
#  mjob_id = mjob identifier
#  status= ok | none | error  (none means that it's not possible to forecast, typically mjob is not started) 
#  forcaster =  name of forcaster, (only average)
#  duration = duration_to_completion (in second)
#  end_time = time to completion (unix time in sec)
#  data = complementary forecaster's information  
#  		for average forcaster: 
#  			average and standard deviation
#
#################################@
#
# requirements:
# 	ruby1.8 (or greater)
# 	libdbi-ruby
# 	libdbd-mysql-ruby or libdbd-pg-ruby
# 	libyaml-ruby
#####################################################
#
# CONFIGURATION
#
#####################################################

load "/etc/gridforecast.conf"

#$cigri_db = 'cigri'
#$host = 'localhost'
#$login = 'root'
#$passwd = ''

#$verbose = true
$verbose = false

#####################################################

require 'dbi'
require 'time'
require 'optparse'
require 'yaml'
require 'pp'

def to_unix_time(time)
 	year, month, day, hour, minute, sec = time.to_s.split(/ |:|-/)
	unix_sec = Time.local(year, month, day, hour, minute, sec).to_i
	return unix_sec
end

def hmstos(hms)
	h,m,s = hms.to_s.split(/:/)
	return 3600*h.to_i + 60*m.to_i + s.to_i
end

def stodhm(s)
	d = s/(24*3600)
	s -= d * (24*3600)
	h = s / 3600
	m = (s- h * 3600) / 60
	return "#{d} days #{h}:#{m}"
end

def base_connect(dbname_host,login,passwd)
#$conf['DB_BASE_NAME']}:#{$conf['DB_HOSTNAME']}
	return DBI.connect("dbi:Mysql:#{dbname_host}", login,passwd)
end

def get_all_multiplejobs(dbh)
	puts "Get all multiplejobs" if $verbose	
	q = "SELECT MJobsId, MJobsUser, MJobsName, MJobsTSub FROM multipleJobs"
	return dbh.select_all(q)
end

def get_jobs(dbh,multiple_job_id)
	puts "Get jobs of #{multiple_job_id} multiple job" if $verbose	
	q = "SELECT jobId, jobState, jobMJobsId, jobClusterName, jobNodeName, jobRetCode, jobTSub, jobTStart, jobTStop FROM jobs WHERE jobMJobsId=#{multiple_job_id}"
  return dbh.select_all(q)
end

def nb_parameters(dbh,multiple_job_id)
	puts "Get jobs of #{multiple_job_id} multiple job" if $verbose	
	q = "SELECT parametersMJobsId FROM parameters WHERE parametersMJobsId=#{multiple_job_id}"
	return dbh.select_all(q).length
end

def forecast(dbh,mjob)
	mjob_id = mjob['MJobsId']
	nb_waiting = nb_parameters(dbh,mjob_id)
	jobs = get_jobs(dbh,mjob_id)
	terminated = []
	last_terminated = 0
	forcasted = 0
	jobs.each do |job|
			case job['jobState'] 
				when 'Terminated'
					job_stop = to_unix_time(job['jobTStop'])
					last_terminated = job_stop if last_terminated < job_stop  
					terminated << job_stop -to_unix_time(job['jobTStart'])
				when 'Running', 'toLaunch', 'RemoteWaiting', 'Terminated'
					nb_waiting += 1
			end		
	end

	std_dev = 0 
  nb = terminated.length
	# Sum some numbers
	total = terminated.inject {|sum, n| std_dev += n * n; sum + n }
 
	mean = total.to_f / nb.to_f
#puts "\n std_dev.to_f: #{std_dev.to_f} nb.to_f: #{nb.to_f} mean: #{mean}"
	std_dev = Math.sqrt((std_dev.to_f / nb.to_f - mean * mean).abs)
	forcasted = (nb_waiting * mean).to_i if !mean.nan?

	res = { 'mjob_id' => mjob_id, 'forcaster' => 'average', 'duration' => 0, 'end_time' => 0, 
					'data'=> {'average' => "0.0", 'standard_deviation' => "0.0"} }

	if (nb == 0) 
		puts  "Mjob: #{mjob_id} is not started  Remains jobs: nb: #{nb_waiting}" if $verbose

		res['status'] = "none"

	elsif (nb_waiting == 0)
		puts "Mjob: #{mjob_id} is terminated jobs: nb: #{nb}  time: #{total} sec or #{stodhm(total)} mean: #{mean} std dev: #{std_dev}" if $verbose

		res['status'] = "ok"
		res['end_time'] = last_terminated  
		res['data'] =  {'average' => sprintf("%.2f",mean) , 'standard_deviation' => sprintf("%.2f",std_dev) } 
	else
		puts "Mjob: #{mjob_id} Terminated jobs: nb: #{nb}  time: #{total} mean: #{mean} std dev: #{std_dev}" if $verbose
		puts "Mjob: #{mjob_id} Remains 	 jobs: nb: #{nb_waiting} forcasted time: #{forcasted} sec or 	#{stodhm(forcasted)}"  if $verbose
		res['status'] = "ok"
		res['end_time'] =  sprintf("%.0f",Time.now.to_f + forcasted) 
		res['data'] =  {'average' => sprintf("%.2f",mean) , 'standard_deviation' => sprintf("%.2f",std_dev) } 

	end
		puts YAML.dump(res)
end

############################################

puts "\n Grid Foracaster for CIGRI middleware" if $verbose

dbh = base_connect("#{$cigri_db}:#{$host}",$login,$passwd)

#multiple_jobs = get_active_multiplejobs(dbh)

if (ARGV.length != 0)
	forecast(dbh, 'MJobsId' => ARGV[0].to_i )
else
	get_all_multiplejobs(dbh).each do |mjob|
		forecast(dbh,mjob)
	end
end

