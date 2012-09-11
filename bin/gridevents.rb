#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'optparse'
require 'version.rb'

verbose = false
campaign_id = nil
username = nil
fix = false
resubmit = false
eventid = nil

optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} [options]"
  
  opts.on('-v', '--verbose', 'Be verbose') do
    verbose = true
  end

  opts.on( '-c', '--campaign ID', String, 'Show or close events for this campaign ID' ) do |c|
    campaign_id = c
  end
  
  opts.on('-f', '--fix', 'Fix the campaign: close all events on the specified campaign') do
    fix = true
  end

  opts.on('-r', '--resubmit', 'Close all events and resubmit each concerned job') do
    resubmit = true
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

# Campaign id can be passed as an argument (same as -c option)
if campaign_id.nil? && ARGV[0]
  campaign_id=ARGV[0]
end

abort("Missing CAMPAIGN_ID\n" + optparse.to_s) unless campaign_id

url = "/campaigns/#{campaign_id}/events"


begin 
  client = Cigri::Client.new 

    # Close events
    if fix 
      url << "/#{eventid}" if eventid # TODO: Not implemented into API for now
      url << '?resubmit' if resubmit
      response = client.delete(url)
      parsed_response = JSON.parse(response.body)
      if response.code != "202"
        STDERR.puts("Failed to fix campaign #{campaign_id}: #{parsed_response['message']}.")
      else
        puts "#{parsed_response['message']}." if verbose
      end
    # Show events
    else
      response = client.get(url)
      events = JSON.parse(response.body)['items']
      Cigri::Client.print_events(events)
    end
   
rescue Errno::ECONNREFUSED => e
  STDERR.puts("API server not reachable: #{e.inspect}")
rescue Exception => e
  STDERR.puts("Something unexpected happened: #{e.inspect}")
  STDERR.puts e.backtrace
end

