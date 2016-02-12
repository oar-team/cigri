#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'optparse'
require 'version.rb'

verbose = false
campaign_id = nil
#username = nil
fix = false
resubmit = false
event_id = nil
global = false
cluster = nil
job = nil
all = false
blacklist = false

optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} [options]"
  
  opts.on( '-c', '--campaign ID', String, 'Show events for this campaign ID or close them (with -f)' ) do |c|
    campaign_id = c
  end

  opts.on( '-g', '--global', String, 'Show current global events (not specific to a campaign)' ) do
    global = true
  end

  opts.on( '-e', '--event ID', String, 'Show only this event or close it (with -f)' ) do |e|
    event_id = e
  end
  
  opts.on('-f', '--fix', 'Fix: close an event (used with -e) or all the events of a campaign (used with -c)') do
    fix = true
  end

  opts.on('-r', '--resubmit', 'Resubmit each job concerned by the fixed events (needs -f') do
    resubmit = true
  end

  opts.on( '-a', '--all', 'Show all events, even those that are closed (warning: it does not print the current global events)' ) do
    all = true
  end
 
  if ENV["USER"] == "root"
    opts.on('--blacklist-cluster ID',String, 'Manually blacklist a cluster (only root)') do |c|
      cluster = c
      blacklist = true
      fix = false
    end
  
    opts.on('--mark-job-event ID',String, 'Create a manual event on a job (only root)') do |j|
      job = j
      fix = false
    end
  end
  
  opts.on( '--version', 'Display Cigri version' ) do
    puts "#{File.basename(__FILE__)} v#{Cigri::VERSION}"
    exit
  end

  opts.on('-v', '--verbose', 'Be verbose') do
    verbose = true
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

# Exit on bad options combinations
if resubmit and not fix
   $stderr.puts "Error: --resubmit must be used with --fix!"
   exit 2
end

# Campaign id can be passed as an argument (same as -c option)
if campaign_id.nil? && ARGV[0]
  campaign_id=ARGV[0]
end

abort("Missing CAMPAIGN (-c), EVENT (-e) id or --global (-g)\n" + optparse.to_s) unless campaign_id or event_id or global or blacklist or job

url = "/campaigns/#{campaign_id}/events" if campaign_id
url += "?all=1" if campaign_id and all
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

