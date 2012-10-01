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
event_id = nil

optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} [options]"
  
  opts.on('-v', '--verbose', 'Be verbose') do
    verbose = true
  end

  opts.on( '-c', '--campaign ID', String, 'Show or close events for this campaign ID' ) do |c|
    campaign_id = c
  end

  opts.on( '-e', '--event ID', String, 'Show or close only this event' ) do |e|
    event_id = e
  end
   
  opts.on('-f', '--fix', 'Fix: close the event if specified or all events of a campaign') do
    fix = true
  end

  opts.on('-r', '--resubmit', 'Resubmit each job concerned by the fixed events') do
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

abort("Missing CAMPAIGN (-c) or EVENT (-e) id\n" + optparse.to_s) unless campaign_id or event_id

url = "/campaigns/#{campaign_id}/events" if campaign_id
url = "/events/#{event_id}" if event_id

begin 
  client = Cigri::Client.new 

    # Close events
    if fix 
      url << '?resubmit=1' if resubmit
      response = client.delete(url)
      parsed_response = JSON.parse(response.body)
      if response.code != "202"
        STDERR.puts("Failed to fix event(s): #{parsed_response['message']}.")
      else
        puts "#{parsed_response['message']}." if verbose
      end
    # Show events
    else
      response = client.get(url)
      events = JSON.parse(response.body)
      items = events["items"] if events["items"]
      items = [events] if events["id"]
      Cigri::Client.print_events(items)
    end
   
rescue Errno::ECONNREFUSED => e
  STDERR.puts("API server not reachable: #{e.inspect}")
rescue Exception => e
  STDERR.puts("Something unexpected happened: #{e.inspect}")
  STDERR.puts e.backtrace
end

