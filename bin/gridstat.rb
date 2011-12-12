#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'net/http'
require 'optparse'
require 'time'
require 'version.rb'

# Correspondance between full states and their one letter equivalent
STATES = {'cancelled' => 'C', 'in_treatment' => 'R', 'terminated' => 'T', 'paused' => 'P'}
STATES.default = '?'

# Options passed to the command
campaign_id = nil
username = nil
full = false
header = true
dump = false
pretty = false
optparse = OptionParser.new do |opts|
  opts.banner = 'Usage: #{File.basename(__FILE__)} [options] ...'
  
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
  
  opts.on( '-H', '--headerless', 'Remove the columns title' ) do
    header = false
  end
  
  opts.on( '-p', '--pretty', 'Pretty print with a dump' ) do
    pretty = true
  end
  
  opts.on( '-u', '--username USERNAME', String, 'Only print campaigns from USERNAME' ) do |u|
    username = u
  end
  
  opts.on( '--version', 'Display Cigri version' ) do
    puts "#{File.basename(__FILE__)} v#{Cigri::VERSION}"
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

#TODO -H et -d incompatibles

begin 
  client = Cigri::Client.new()
  http=client.http
  response = client.get(url)
  #response = http.request(Net::HTTP::Get.new(url))
  
  if dump
    puts response.body
  else
    if campaign_id  
      campaigns = [JSON.parse(response.body)]
    else
      campaigns = JSON.parse(response.body)['items']
    end

    # Filter the campaigns on the username
    if username
      campaigns.reject!{|h| h['user'].nil? || h['user'] != username}
    end

    if header
      puts "Campaign id Name                User             Submission time     S Progress"
      puts '----------- ------------------- ---------------- ------------------- - --------'
    end 
    
    #TODO sort by campaign ID
    begin 
      campaigns.each do |campaign|
        begin 
          progress = campaign['finished_jobs'] * 100.0 / campaign['total_jobs']
        rescue ZeroDivisionError => e
          progress = nil
        end
        printf("%-11d %-19s %-16s %-19s %s %7.2f%\n", 
                campaign['id'], 
                campaign['name'][0..18], 
                campaign['user'][0..15], 
                Time.at(campaign['submission_time']).strftime('%Y-%m-%d %H-%M-%S'), 
                STATES[campaign['state']], 
                progress);
      end
    rescue Errno::EPIPE
      exit
    end
  end
rescue Errno::ECONNREFUSED => e
  STDERR.puts("API server not reachable: #{e.inspect}")
rescue Exception => e
  STDERR.puts("Something unexpected happened: #{e.inspect}")
  STDERR.puts e.backtrace
end
