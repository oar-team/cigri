#!/usr/bin/ruby -w

$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'

abort("Usage: #{File.basename(__FILE__)} <CAMPAIGN_ID>") unless ARGV.length == 1

id = ARGV[0]

db_connect() do |dbh|
  res = delete_campaign(dbh, ENV["SUDO_USER"], id)
  if res == nil
    puts "Campaign #{id} does not exist"
  elsif res
    puts "Campaign #{id} deleted"
  else
    puts "Campaign #{id} does not belong to you"
  end
end

