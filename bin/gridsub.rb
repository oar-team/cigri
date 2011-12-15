#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'optparse'
require 'version.rb'

jsons = []
campaign_id = nil
jobs = []
details = false
optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} <-j JDL | -f JDL_FILE> [options]"
  
  opts.on( '-c', '--campaign CAMPAIGN_ID', 'Add jobs in an existing campaign' ) do |id|
    campaign_id = id
  end

  opts.on( '-d', '--details', 'Prints all the JSON of the campaign instead of just the ID' ) do
    details = true
  end
  
  opts.on( '-f', '--file JDL_FILE', 'JDL File containing the JSON' ) do |file|
    jsons << File.read(file)
  end

  opts.on( '-F', '--jobfile JDL_FILE', 'JDL File containing an array of parameters' ) do |file|
    jobs << File.read(file)
  end
  
  opts.on( '-j', '--json JSON', 'JSON String' ) do |json|
    jsons << json
  end

  opts.on( '-J', '--jsonjob JSON', 'JSON String containing an array of parameters' ) do |job|
    jobs << job
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
  STDERR.puts e
  STDERR.puts "\n" + optparse.to_s
  exit 1
end

def submit_campaign(jdl, campaign_id=nil)
  client = Cigri::Client.new
  
  url = '/campaigns'
  url += "/#{campaign_id}/jobs" if campaign_id

  client.post(url, jdl, 'Content-Type' => 'application/json')
end

def print_response(response, details)
  
end

if jsons.length == 0 and jobs.length == 0
  STDERR.puts "Please provide at least one JSON or JDL_FILE, or an array of parameters" 
  STDERR.puts optparse.to_s
end
STDERR.puts "Please provide a campaign ID to add jobs in it" if jobs.length > 0 and campaign_id.nil?

begin
  jsons.each do |json|
    response = submit_campaign(json)
    if response.code == "201"
        puts "Campaign successfully submitted"
        puts response.body if details
        puts "CAMPAIGN_ID=#{JSON.parse(response.body)['id']}"
    else
      STDERR.puts("Error submitting campaign: #{response.body}")
    end
  end
  jobs.each do |job|
    response = submit_campaign(job, campaign_id)
    if response.code == "201"
      puts "Jobs successfully added to campaign #{campaign_id}"
      puts response.body if details
    else
      STDERR.puts("Error submitting campaign: #{response.body}")
    end
  end
rescue Errno::ECONNREFUSED => e
  STDERR.puts("API server not reachable: #{e.inspect}")
rescue Exception => e
  STDERR.puts("Something unexpected happened: #{e.inspect}")
  STDERR.puts e.backtrace
end

