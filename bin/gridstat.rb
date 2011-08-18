#!/usr/bin/ruby -w

$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'
require 'json'
require 'net/http'
require 'optparse'
require 'time'

#TOTO get those values from config file
CIGRIHOST = 'localhost'
CIGRIHOSTPORT = 9292

# Correspondance between full states and their one letter equivalent
STATES = {'cancelled' => 'C', 'in_treatment' => 'R', 'terminated' => 'T', 'paused' => 'P'}
STATES.default = '?'

campaign_id = nil
username = nil
optparse = OptionParser.new do |opts|
  opts.banner = 'Usage: gridstat [options] ...'
  opts.version = "v#{Cigri::VERSION}"
  
  opts.on( '-u', '--username USERNAME', String, 'Only print campaigns from USERNAME' ) do |u|
    username = u
  end

  opts.on( '-c', '--campaign ID', String, 'Only print informations for campaign ID' ) do |c|
    campaign_id = c
  end
  
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

begin
  optparse.parse!(ARGV)
rescue OptionParser::ParseError => e
  $stderr.puts e
  $stderr.puts "\n" + optparse.to_s
  exit 1
end

#TODO manage errors (not reachable, campaign not found...)
if campaign_id
  request = Net::HTTP.get(CIGRIHOST, "/campaigns/#{campaign_id}", CIGRIHOSTPORT)
  campaigns = [JSON.parse(request)]
else
  request = Net::HTTP.get(CIGRIHOST, "/campaigns", CIGRIHOSTPORT)
  campaigns = JSON.parse(request)['items']
end

if username
  campaigns.reject!{|h| h['user'].nil? || h['user'] != username}
end

puts "Campaign id Name           User           Submission time     S Progress"
puts '----------- -------------- -------------- ------------------- - ----------'
campaigns.each do |campaign|
  printf("%-11d %-14s %-14s %-19s %s %s\n", 
          campaign['id'], 
          campaign['name'], 
          campaign['user'], 
          Time.at(campaign['submission_time']).strftime('%Y-%m-%d %H-%M-%S'), 
          STATES[campaign['state']], 
          'Progress');
end

#


