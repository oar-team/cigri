#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'optparse'
require 'version.rb'

verbose = false
optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} <CAMPAIGN_ID> [CAMPAIGN_IDS...] [options]"
  
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

abort("Missing CAMPAIGN_ID\n" + optparse.to_s) unless ARGV.length > 0

begin 
  client = Cigri::Client.new 
 
  ARGV.each do |campaign_id|
    puts "Getting the terminated jobs..."
    response=client.get("/campaigns/#{campaign_id}/jobs/finished")
    jobs=JSON.parse(response.body)
    puts "Sorting jobs by clusters..."
    jobs_of_cluster={}
    cluster_ids=jobs["items"].map{|j| j["cluster_id"]}.uniq
    cluster_ids.each do |cluster_id|
      jobs_of_cluster[cluster_id]=jobs["items"].select{|j| j["cluster_id"]==cluster_id}
    end
    jobs_of_cluster.each_key do |c|
      joblist=[]
      jobs_of_cluster[c].each {|j| joblist << j["remote_id"] if j["remote_id"] }
      cluster_jobs=[]
      joblist.each_slice(100) do |chunk|
         puts "Getting #{chunk} from cluster #{c}..."
         # Get jobs
         #TODO: get_joblist gateway into the Cigri API must be coded...
      end
    end
    # For each cluster, get the jobs infos
       #if cluster.props[:api_chunk_size] and cluster.props[:api_chunk_size].to_i > 0
       #  joblist=[]
       #  current_jobs.each {|j| joblist << j.props[:remote_id] if j.props[:remote_id] }
       #  joblist.each_slice(cluster.props[:api_chunk_size].to_i) do |chunk|
       #    cluster.fill_jobs_cache(:ids => chunk)
       #  end
       #end
    
    

  end
rescue Errno::ECONNREFUSED => e
  STDERR.puts("API server not reachable: #{e.inspect}")
rescue Exception => e
  STDERR.puts("Something unexpected happened: #{e.inspect}")
  STDERR.puts e.backtrace
end

