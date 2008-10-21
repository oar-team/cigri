#!/usr/bin/ruby -w
# 

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
#require 'cigriClusters'
require 'cigriUtils'

$tag="[COLLECTOR]   "

#########################################################################
# MAIN
#########################################################################

# Connect to database
dbh = base_connect("#{$cigri_db}:#{$host}",$login,$passwd)

#cluster=Cluster.new(dbh,"zephir.mirage.ujf-grenoble.fr")
#if cluster.active?(415)
#  puts "ACTIVE"
#end

tocollectJobs=tocollect_Jobs(dbh)
tocollectJobs.remove_blacklisted
tocollectJobs.each do |job|
  repository="~cigri/results/#{job.user}/#{job.mjobid}"
  if job.execdir == "~"
    job.execdir = "~#{job.localuser}"
  end
  if job.name.to_s != ""
    puts "#{job.cluster}:#{job.execdir}/#{job.name} #{repository}"
  end
  if job.batchtype.to_s == "OAR2"
    puts  "#{job.cluster}:#{job.execdir}/OAR*.#{job.jid}.stderr #{repository}"
    puts  "#{job.cluster}:#{job.execdir}/OAR*.#{job.jid}.stdout #{repository}"
  else
    puts "#{$tag}Warning: #{job.batchtype} batch type files not collected"
  end
end
