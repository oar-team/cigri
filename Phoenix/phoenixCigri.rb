#!/usr/bin/ruby -w
# 
####################################################################################
# CIGRI Phoenix module.
# This script manages the checkpoints
#
# Requirements:
#        ruby1.8 (or greater)
#        libdbi-ruby
#        libdbd-mysql-ruby or libdbd-pg-ruby
#        libyaml-ruby
#
#        $iolib_dir/cigriJobs.rb
#        ../ClusterQuery/jobCheckpoint.pl (a command that takes 3 arguments:
#                                  cluster,user,jobBatchId and sends oardel -c)
#
# ###################################################################################

#####################################################################################
#
# CONFIGURATION
#
#####################################################################################

# You can store the configuration on a separate file or comment out the configuration
# variables below
if ENV['CIGRIDIR']
then
  load "#{ENV['CIGRIDIR']}/cigri_rb.conf"
else
  load "/etc/cigri_rb.conf"
end

# Database configuration
#$cigri_db = 'cigri'
#$host = 'localhost'
#$login = 'root'
#$passwd = ''

# Verbosity (for debuging purpose)
#$verbose = false
$verbose = true

$tag="[PHOENIX]     "

#######################################################################################
# Includes loading
#######################################################################################

$:.replace([$iolib_dir] | $:)

require 'dbi'
require 'time'
require 'optparse'

require 'cigriJobs'


#########################################################################
# Functions
#########################################################################


#########################################################################
# MAIN
#########################################################################

# Connect to database
dbh = base_connect("#{$cigri_db}:#{$host}",$login,$passwd)

jobs=JobSet.new(dbh,"SELECT * FROM jobs order by jobId desc limit 10")
jobs.do
puts jobs.to_s

mjob=MultipleJob.new(dbh,123)
puts mjob.to_s
