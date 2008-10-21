#!/usr/bin/ruby -w
# 

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

# Size of the window in seconds on wich the job throughput is calculated
# time_window_size = 3600

# Verbosity (for debuging purpose)
$verbose = false
#$verbose = true

#######################################################################################
# Includes loading
#######################################################################################

$:.replace([$iolib_dir] | $:)

require 'dbi'
require 'time'
require 'optparse'
require 'yaml'
require 'pp'

require 'cigriJobs'
require 'cigriClusters'
require 'cigriUtils'


#########################################################################
# MAIN
#########################################################################

# Connect to database
dbh = base_connect("#{$cigri_db}:#{$host}",$login,$passwd)

cluster=Cluster.new(dbh,"idpot.imag.fr")
if cluster.active?
  puts "ACTIVE"
end

tocollect_MJobs(dbh).each do |mjob|
  puts mjob
end
