#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'optparse'
require 'version.rb'

verbose = false
hold = false
resume = false
job_id=false
optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} <CAMPAIGN_ID> [CAMPAIGN_IDS...] [options]"
  
  opts.on('-v', '--verbose', 'Be verbose') do
    verbose = true
  end
  
  opts.on('-p', '--pause', 'Holds the campaign') do
    hold = true
  end

  opts.on('-r', '--resume', 'Resumes the campaign (only if it is paused)') do
    resume = true
  end

  opts.on( '-j', '--job ID', String,  'Cancel a single job' ) do |j|
    job_id=j
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

abort("Missing CAMPAIGN_ID\n" + optparse.to_s) unless ARGV.length > 0 or job_id

status=""
status="?hold=1" if hold
status="?resume=1" if resume

begin 
  client = Cigri::Client.new 
  response='' 

  if job_id
    response = client.delete("/jobs/#{job_id}")
    parsed_response = JSON.parse(response.body)
    if response.code != "202"
       STDERR.puts("Failed to cancel job #{job_id}: #{parsed_response['message']}.")
    else
      puts "#{parsed_response['message']}." if verbose
    end
  else
    ARGV.each do |campaign_id|
      response = client.delete("/campaigns/#{campaign_id}#{status}")
      parsed_response = JSON.parse(response.body)
      if response.code != "202"
         STDERR.puts("Failed to cancel campaign #{campaign_id}: #{parsed_response['message']}.")
      else
        puts "#{parsed_response['message']}." if verbose
      end
    end
  end
rescue Errno::ECONNREFUSED => e
  STDERR.puts("API server not reachable: #{e.inspect}")
rescue Exception => e
  STDERR.puts("Something unexpected happened: #{e.inspect}")
  STDERR.puts e.backtrace
end

