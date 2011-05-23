#!/usr/bin/ruby -w

$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'

abort("Usage: #{File.basename(__FILE__)} <CAMPAIGN_ID>") unless ARGV.length == 1

id = ARGV[0]

db_connect() do |dbh|
  res = delete_campaign(dbh, id)
  if res
    puts "Campaign #{id} deleted"
  else
    puts "Campaign #{id} does not exist"
  end
end

