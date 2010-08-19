#!/usr/bin/ruby
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
require 'cigriJobs'
require 'cigriUtils'

#$verbose = false
$verbose = true
$tag="[PHOENIX]     "
$checkpoint_cmd=File.dirname($0)+"/../ClusterQuery/jobCheckpoint.pl"


#########################################################################
# Functions
#########################################################################


#########################################################################
# MAIN
#########################################################################

# Connect to database
dbh = db_init()

# For each checkpointable job
puts "#{$tag}Checking if there are jobs to checkpoint" if $verbose
get_checkpointable_jobs(dbh).each do |job|

  # First, we update the cdate if it is empty
  if job.cdate.nil? || job.cdate == 0
    job.update_checkpoint_date(dbh,Time.now.to_i)
    puts "#{$tag}Initiating checkpoint date for new job #{job.jid}" if $verbose
  end

  # Send checkpoints if period is reached
  if Time.now.to_i - job.cdate > job.cperiod
    puts "#{$tag}Sending checkpoint signal to job #{job.jid}" if $verbose
    system($checkpoint_cmd,job.cluster,job.user,job.batchid.to_s)
    job.update_checkpoint_date(dbh,Time.now.to_i)
  end

end
