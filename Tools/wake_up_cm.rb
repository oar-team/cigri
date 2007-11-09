#!/usr/bin/ruby -w
# 
####################################################################################
# CIGRI wake up nodes of a cmserver
#
# Requirements:
#        ruby1.8 (or greater)
#        libdbi-ruby
#        libdbd-mysql-ruby or libdbd-pg-ruby
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

# Clusters to wake up
clusters={ 
     # "idpot.imag.fr" => "sudo hostname", 
     "cmserver.e-ima.ujf-grenoble.fr" => "sudo /usr/local/sbin/wake_up_all_nodes.sh" 
         }

#######################################################################################

$:.replace([$iolib_dir] | $:)

require 'dbi'
require 'time'
require 'optparse'
require 'yaml'
require 'pp'

require 'cigriJobs.rb'

# Make an array of running multiplejobs
#
def get_Running_MultipleJobs_for_Cluster(dbh,cluster)
  mjobs=[]
  query = "select propertiesMJobsId from properties,multipleJobs where propertiesMJobsId=MJobsId and MJobsState='IN_TREATMENT' and propertiesClusterName='#{cluster}';"
  sql_mjobs = dbh.select_all(query)
  sql_mjobs.each do |sql_mjob|
    mjobs << MultipleJob.new(dbh,sql_mjob['propertiesMJobsId'])
  end
  return mjobs
end


#########################################################################
# MAIN
#########################################################################

# Connect to database
dbh = base_connect("#{$cigri_db}:#{$host}",$login,$passwd)

# Wake up clusters
clusters.each do |cluster,cmd|
  get_Running_MultipleJobs_for_Cluster(dbh,cluster).each do |mjob|
    puts "Sending '#{cmd}' on #{cluster}"
    output=`ssh #{cluster} #{cmd}`
    puts output
  end
end

