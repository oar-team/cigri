#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'optparse'
require 'time'
require 'version.rb'

# Correspondance between full states and their one letter equivalent
STATES = {'cancelled' => 'C', 'in_treatment' => 'R', 'terminated' => 'T', 'paused' => 'P'}
STATES.default = '?'

# Options passed to the command
campaign_id = nil
job_id=nil
username = nil
full = false
header = true
dump = false
pretty = false
events = false
offset = nil
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options] [<campaign ID>]"
  
  opts.on( '-c', '--campaign ID', String, 'Only print informations for campaign ID' ) do |c|
    campaign_id = c
  end
  
  opts.on( '-d', '--dump', 'Dump the result as JSON' ) do
    dump = true
  end
  
  opts.on( '-f', '--full', 'Display all info of a campaign (used with -c)' ) do
    full = true
  end

  opts.on( '-o', '--offset OFFSET', 'Print jobs starting at this offset (used with -f)' ) do |o|
    offset = o
  end
  
  opts.on( '-e', '--events', 'Print open events on a campaign' ) do
    events = true
  end

  opts.on( '-j', '--job ID', String,  'Print infos about a job' ) do |j|
    job_id=j
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

# Campaign id can be passed as an argument (same as -c option)
if campaign_id.nil? && job_id.nil? && ARGV[0]
  campaign_id=ARGV[0]
end

# Events printing needs a campaign ID
if events
  if not campaign_id
    $stderr.puts "You must give a campaign id to print the events!"
    exit 1
  end
end

# Prevent full output of all campaigns!
if full and not campaign_id
  $stderr.puts "You must provide a campaign id with --full!"
  exit 1
end

url = '/campaigns'
url << "/#{campaign_id}" if campaign_id
url << "/events" if events
url << "/jobs" if full and dump
url << '?pretty' if dump and pretty
url << "&offset=#{offset}" if offset and dump and pretty
url << "?offset=#{offset}" if offset and dump and not pretty

url = "/jobs/#{job_id}" if job_id

begin 
  client = Cigri::Client.new()
  response = client.get(url)
  
  if dump
    puts response.body
  elsif events
    events = JSON.parse(response.body)['items']
    Cigri::Client.print_events(events)
  elsif job_id
    j = JSON.parse(response.body)
    Cigri::Client.print_job(j)
  else
    if campaign_id  
      campaigns = [JSON.parse(response.body)]
      if campaigns[0]['status'] == 404
        STDERR.puts("Campaign #{campaign_id} not found!")
        exit
      end
    else
      campaigns = JSON.parse(response.body)['items']
    end

    # Filter the campaigns on the username
    if username
      campaigns.reject!{|h| h['user'].nil? || h['user'] != username}
    end

    if header and !full and !dump and !campaign_id
      puts "Campaign id Name                User             Submission time     S  Progress"
      puts '----------- ------------------- ---------------- ------------------- -- --------'
    end 
    
    begin 
      campaigns.sort_by{|c| c['id']}.each do |campaign|
        begin 
          progress = campaign['finished_jobs'] * 100.0 / campaign['total_jobs']
        rescue ZeroDivisionError => e
          progress = nil
        end
        e=' '
        e='e' if campaign['has_events']
        progress = 0 if campaign['total_jobs'] == 0
        if !campaign_id
          printf("%-11d %-19s %-16s %-19s %s %d/%d (%d\%%)\n", 
                  campaign['id'], 
                  campaign['name'][0..18], 
                  campaign['user'][0..15], 
                  Time.at(campaign['submission_time']).strftime('%Y-%m-%d %H-%M-%S'), 
                  STATES[campaign['state']]+e, 
                  campaign['finished_jobs'],campaign['total_jobs'],progress);
        else
          e="(events)" if e=='e'
          printf("Campaign: %d\n Name: %s\n User: %s\n Date: %s\n State: %s %s\n Progress: %d/%d (%d\%%)\n",
                  campaign['id'], 
                  campaign['name'], 
                  campaign['user'], 
                  Time.at(campaign['submission_time']).strftime('%Y-%m-%d %H-%M-%S'), 
                  campaign['state'],e, 
                  campaign['finished_jobs'],campaign['total_jobs'],progress);
          if full
            puts " Jobs:"
            items=[]
            offset_string="?offset=#{offset}" if offset
            response = client.get("/campaigns/#{campaign['id']}/jobs#{offset_string}")
            jobs=JSON.parse(response.body)
            items=jobs["items"]
            c=0
            max=10
            while jobs and jobs["links"] and jobs["links"].detect{|l| l["rel"]=="next"} and c < max
              c+=1
              url=jobs["links"].select{|l| l["rel"]=="next"}[0]["href"]
              response = client.get(url)
              jobs=JSON.parse(response.body)
              items=items+jobs["items"] if jobs["items"]
            end
           if items.nil?
             puts "No jobs to print"
           else
             items.each do |job|
                printf("  %d: %s,%s,%s,%s,%s,%s\n",
                         job["id"],
                         job["cigri_job_id"] || "*",
                         job["remote_id"] || "*",
                         job["state"],
                         job["cluster"] || "*",
                         job["name"],
                         job["parameters"])
             end
           end
           if jobs and jobs["links"] and jobs["links"].detect{|l| l["rel"]=="next"} and jobs["offset"]
             puts "WARNING: more jobs left. Next jobs with --offset=#{jobs['offset'].to_i+jobs['limit'].to_i}"
           end
            
          end
        end
      end
    rescue Errno::EPIPE
      exit
    end
  end
rescue SystemExit
rescue Errno::ECONNREFUSED => e
  STDERR.puts("API server not reachable: #{e.inspect}")
rescue Exception => e
  STDERR.puts("Something unexpected happened: #{e.inspect}")
  STDERR.puts e.backtrace
end
