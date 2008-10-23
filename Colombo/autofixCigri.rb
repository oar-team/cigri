#!/usr/bin/ruby -w
# 
####################################################################################
# CIGRI autofix Colombo script.
# This script checks some events and re-check periodicaly
# to try fixing them automatically
# For the moment, it only checks for SSH events.
#
# Requirements:
#        ruby1.8 (or greater)
#        libdbi-ruby
#        libdbd-mysql-ruby or libdbd-pg-ruby
#        libyaml-ruby
#        ./autofixCheckSSH.pl (a wrapper using cigri perl libs)
# ###################################################################################

##################################################################################
# CONFIGURATION AND INCLUDES LOADING
##################################################################################
if ENV['CIGRIDIR']
  require ENV['CIGRIDIR']+'/ConfLib/cigriConflib.rb'
else
  require File.dirname($0)+'/../ConfLib/cigriConflib.rb'
end
$:.replace([get_conf("INSTALL_PATH")+"/Iolib/"] | $:)

require 'dbi'
require 'time'
require 'optparse'
require 'cigriJobs'
require 'cigriUtils'

#$verbose = false
$verbose = true

if get_conf("AUTOFIX_DELAY")
  $time_window_size=get_conf("AUTOFIX_DELAY").to_i
else
  $time_window_size=600
end

$tag="[AUTOFIX]     "


#########################################################################
# Functions
#########################################################################

def check_ssh(cluster)
  puts "#{$tag}Checking SSH on cluster #{cluster}" if $verbose
  return system(File.dirname($0)+"/autofixCheckSSH.pl",cluster)
end

def fix_event(dbh,eventId)
  puts "#{$tag}Fixing event #{eventId}" if $verbose
  query = "UPDATE events SET eventState='FIXED' where eventId=#{eventId}"
  dbh.do(query)
end

def update_lastcheked_event(dbh,eventId)
  puts "#{$tag}Updating last checked date for non-fixed event #{eventId}" if $verbose
  date = Time.now.to_i
  query = "UPDATE events SET eventAdminNote='LastCheck:#{date}' where eventId=#{eventId}"
  dbh.do(query)
end

#########################################################################
# MAIN
#########################################################################

# Connect to database
dbh = db_init()

# Get SSH ToFIX events
query = "SELECT eventId,unix_timestamp(eventDate) as date,eventAdminNote,eventClusterName FROM events 
              WHERE eventType='SSH'
	      AND eventState='ToFIX'"
sql_events=dbh.select_all(query)

# For each event
checked=0
if !sql_events.empty?
  sql_events.each do |event|

    # Catch the last check date into the text field eventAdminNote
    lastchecked=event['date']
    if !event['eventAdminNote'].nil?
      scanres=event['eventAdminNote'].scan(/LastCheck:(\d+)/)
      if !scanres.empty?
        lastchecked=scanres[0][0].to_i
      end
    end

    # Check, if it's time to do so
    $autofix_delay=600 if $autofix_delay.nil?
    if Time.now.to_i  - lastchecked > $autofix_delay
      checked += 1
      if check_ssh(event['eventClusterName'])
        fix_event(dbh,event['eventId'])
      else
        update_lastcheked_event(dbh,event['eventId'])
      end
    end
    if checked == 0 && $verbose
      puts "#{$tag}SSH event #{event['eventId']} will be checked later (less than #{$autofix_delay} seconds)"
    end
  end

# No event
else
  puts "#{$tag}No SSH event to check, good." if $verbose
end
