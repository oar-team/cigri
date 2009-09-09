#!/usr/bin/ruby -w
# 
####################################################################################
# This is a maintenance script to remove old entries
# of the gridstatus table.
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

$verbose = false

require 'dbi'
require 'time'
require 'optparse'
require 'yaml'
require 'pp'
require 'cigriUtils'

if get_conf("GRIDSTATUS_RETENTION_DAYS")
  $gridstatus_retention_days=get_conf("GRIDSTATUS_RETENTION_DAYS").to_i
else
  $gridstatus_retention_days=365
end
if get_conf("GRIDSTATUS_PRUNE_DAYS")
  $gridstatus_prune_days=get_conf("GRIDSTATUS_PRUNE_DAYS").to_i
else
  $gridstatus_prune_days=180
end
if get_conf("GRIDSTATUS_PRUNE_PERIOD")
  $gridstatus_prune_period=get_conf("GRIDSTATUS_PRUNE_PERIOD").to_i
else
  $gridstatus_prune_period=3600
end


#########################################################################
# Main
#########################################################################

# Connect to database
dbh = db_init()

# Remove old entries (more than GRIDSTATUS_RETENTION_DAYS)
query = "delete from gridstatus where unix_timestamp(now()) - timestamp > #{$gridstatus_retention_days*3600*24}"
dbh.execute(query)

#TODO
# Keep one entry every $gridstatus_prune_period seconds for entries older than $gridstatus_prune_days days
# to have a reasonnable sampling
