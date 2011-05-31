#!/usr/bin/ruby -w

$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'

abort("Usage: #{File.basename(__FILE__)} <CAMPAIGN_ID> [CAMPAIGN_IDS...]") unless ARGV.length >= 1

db_connect() do |dbh|
  for id in ARGV do
    res = delete_campaign(dbh, ENV["SUDO_USER"], id)
    if res == nil
      puts "Campaign #{id} does not exist"
    elsif res
      puts "Campaign #{id} deleted"
    else
      puts "Campaign #{id} does not belong to you"
    end
  end
end

