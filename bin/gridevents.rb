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
global = false
cluster = nil
job = nil
blacklist = false

optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} [options]"
  
  opts.on('-v', '--verbose', 'Be verbose') do
    verbose = true
  end

  opts.on( '-c', '--campaign ID', String, 'Show or close events for this campaign ID' ) do |c|
    campaign_id = c
  end

  opts.on( '-g', '--global', String, 'Show current global events (not specific to a campaign)' ) do
    global = true
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

  opts.on('--blacklist-cluster ID',String, 'Manually blacklist a cluster (only root)') do |c|
    cluster = c
    blacklist = true
    fix = false
  end

  opts.on('--mark-job-event ID',String, 'Create a manual event on a job (only root)') do |j|
    job = j
    fix = false
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

abort("Missing CAMPAIGN (-c), EVENT (-e) id or --global (-g)\n" + optparse.to_s) unless campaign_id or event_id or global or blacklist or job

url = "/campaigns/#{campaign_id}/events" if campaign_id
url = "/events/#{event_id}" if event_id
url = "/events" if global or blacklist or job

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

    # Create an event for blacklisting a cluster
    elsif blacklist
      event={"class" => 'cluster', "cluster_id" => cluster.to_i, "code" => "CLUSTER_MANUALLY_DISABLED", "message" => "Cluster #{cluster} disabled by the administrator of the grid. Please, be patient."}.to_json
      response = client.post(url,event,'Content-Type' => 'application/json')
      parsed_response = JSON.parse(response.body)
      if response.code != "201"
        STDERR.puts("Failed to add event: #{parsed_response['message']}.")
        exit 1
      end   

    # Create a manual event on a job
    elsif job
      event={"class" => 'job', "job_id" => job.to_i, "code" => "MANUAL_EVENT", "message" => "The job has been marked in the event state by the administrator."}.to_json
      response = client.post(url,event,'Content-Type' => 'application/json')
      parsed_response = JSON.parse(response.body)
      if response.code != "201"
        STDERR.puts("Failed to add event: #{parsed_response['message']}.")
        exit 1
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

