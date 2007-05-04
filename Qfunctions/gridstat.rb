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

#####################################################################################
#
# CONFIGURATION
#
#####################################################################################

# You can store the configuration on a separate file or comment out the configuration
# variables below
load "/etc/cigri_rb.conf"

# Database configuration
#$cigri_db = 'cigri'
#$host = 'localhost'
#$login = 'root'
#$passwd = ''

# Verbosity (for debuging purpose)
$verbose = false
#$verbose = true

#######################################################################################

require 'dbi'
require 'time'
require 'optparse'
require 'yaml'
require 'pp'

require '../Iolib/cigriJobs.rb'

module ExtendedJob
    attr_reader :jid, :param, :cluster, :batchid, :node
   
    def set_properties(param,cluster,batchid,node)
        @param=param
        @cluster=cluster
        @batchid=batchid
        @node=node
    end
end

module ExtendedMjob
    def update_jobs
        query = "SELECT jobId, jobMJobsId,jobState,jobTSub,jobTStart,jobTStop,jobParam,jobClusterName,jobBatchid,jobNodeName\
                 FROM jobs \
                 WHERE jobMJobsId=#{@mjobid}"
        sql_jobs=@dbh.select_all(query)

        # Job objects creation and parsing
        @jobs=[]
        sql_jobs.each do |sql_job|
            job=Job.new(sql_job['jobId'],\
                        @mjobid,\
                        sql_job['jobState'],\
                        to_unix_time(sql_job['jobTSub']),\
                        to_unix_time(sql_job['jobTStart']),\
                        to_unix_time(sql_job['jobTStop']))
            job.extend ExtendedJob
            job.set_properties(sql_job['jobParam'],sql_job['jobClusterName'],sql_job['jobBatchid'],sql_job['jobNodeName'])
            @jobs << job
        end
    end
end

#########################################################################
# MAIN
#########################################################################

# Connect to database
dbh = base_connect("#{$cigri_db}:#{$host}",$login,$passwd)

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
mjob.extend ExtendedMjob
mjob.update_jobs

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
