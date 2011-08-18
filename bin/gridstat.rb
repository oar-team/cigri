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

# Options passed to the command
campaign_id = nil
username = nil
full = false
dump = false
pretty = false
optparse = OptionParser.new do |opts|
  opts.banner = 'Usage: gridstat [options] ...'
  
  opts.on( '-c', '--campaign ID', String, 'Only print informations for campaign ID' ) do |c|
    campaign_id = c
  end
  
  opts.on( '-d', '--dump', 'Dump the result as JSON' ) do
    dump = true
  end
  
  #TODO manage full description
  opts.on( '-f', '--full', 'Display all info on a campaign' ) do
    full = true
  end
  
  opts.on( '-p', '--pretty', 'Pretty print with a dump' ) do
    pretty = true
  end
  
  opts.on( '-u', '--username USERNAME', String, 'Only print campaigns from USERNAME' ) do |u|
    username = u
  end
  
  opts.on( '-v', '--version', 'Display Cigri version' ) do
    puts "gridstat v#{Cigri::VERSION}"
    exit
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

url = '/campaigns'
url << "/#{campaign_id}" if campaign_id
url << '?pretty' if dump and pretty
request = Net::HTTP.get(CIGRIHOST, url, CIGRIHOSTPORT)

if dump
  puts request
else
  #TODO manage errors (not reachable, campaign not found...)
  if campaign_id  
    campaigns = [JSON.parse(request)]
  else
    campaigns = JSON.parse(request)['items']
  end

  # Filter the campaigns on the username
  if username
    campaigns.reject!{|h| h['user'].nil? || h['user'] != username}
  end

  puts "Campaign id Name                User             Submission time     S Progress"
  puts '----------- ------------------- ---------------- ------------------- - --------'
  campaigns.each do |campaign|
    printf("%-11d %-19s %-16s %-19s %s %s\n", 
            campaign['id'], 
            campaign['name'][0..18], 
            campaign['user'][0..15], 
            Time.at(campaign['submission_time']).strftime('%Y-%m-%d %H-%M-%S'), 
            STATES[campaign['state']], 
            'Progress');
  end
end
