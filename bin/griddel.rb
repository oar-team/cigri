#!/usr/bin/ruby -w

$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'

abort("Usage: #{File.basename(__FILE__)} <CAMPAIGN_ID>") unless ARGV.length == 1

id = ARGV[0]

db_connect() do |dbh|
  id = delete_campaign(dbh, id)
  puts "Campaign ##{id} deleted" if id
end

