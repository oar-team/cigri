#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'optparse'
require 'version.rb'

verbose = false
hold = false
resume = false
purge = false
job_id=false
campaign_ids=[]
optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} [options]"

  opts.on('-c', '--campaign_ids id1,id2,...', Array, 'Campaigns on which to act') do |c|
    campaign_ids=c
  end
 
  opts.on('-p', '--pause', 'Holds the campaign') do
    hold = true
  end

  opts.on('-r', '--resume', 'Resumes the campaign (only if it is paused)') do
    resume = true
  end

  opts.on('--purge', 'Purge the campaign (only if it is finished)') do
    purge = true
  end

  opts.on( '-j', '--job ID', String,  'Cancel a single job' ) do |j|
    job_id=j
  end

  opts.on('-v', '--verbose', 'Be verbose') do
    verbose = true
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

abort("Error: You need to provide at least one campaign_id or job_id!\n" + optparse.to_s) unless ARGV.length > 0 or campaign_ids.length > 0 or job_id

if campaign_ids.length == 0
  campaign_ids=ARGV
end

status=""
status="?hold=1" if hold
status="?resume=1" if resume
status="?purge=1" if purge

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
    campaign_ids.each do |campaign_id|
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

