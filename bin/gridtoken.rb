#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'optparse'
require 'version.rb'

verbose = false
cluster_id = nil
token = false
list = false
remove = false

optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} [options]"
  
  opts.on('-v', '--verbose', 'Be verbose') do
    verbose = true
  end

  opts.on( '-l', '--list', String, 'List notifications' ) do |l|
    list = true
  end

  opts.on( '-i', '--cluster-id <id>', Integer, 'Cluster to configure, selected by its id. (Use `gridcluster` to get clusters id)' ) do |i|
    cluster_id = i
  end
   
  opts.on('-r', '--remove', 'Remove the token') do |r|
    remove = true
  end

  opts.on('-t', '--token <token string>', String, 'Token string') do |t|
    token = t
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

if (not cluster_id or not token) and not list 
  puts optparse.help
  exit
end

url = "/tokens"

begin 
  client = Cigri::Client.new 
  if list
    response = client.get(url+"?pretty=true")
    parsed_response = JSON.parse(response.body)
    if not parsed_response["items"].empty?
      puts "You have the following tokens:"
    end
    parsed_response["items"].each do |t|
      puts " - Cluster ##{t["cluster_id"]} : #{t["cluster_login"].split(/ /, 2)[1]}"
    end
  elsif remove
    response = client.delete(url+"?cluster_id="+cluster_id)
  else
    body={"cluster_id" => cluster_id, "token" => token}.to_json
    response = client.post(url,body, 'Content-Type' => 'application/json')
    #parsed_response = JSON.parse(response.body)
    if response.code != "201"
      STDERR.puts("Failed to register token on cluster #{cluster_id}: #{response.inspect}.")
    else
      parsed_response = JSON.parse(response.body)
      puts "#{parsed_response['message']}."
    end
    puts "#{parsed_response['message']}." if verbose
  end
rescue Errno::ECONNREFUSED => e
  STDERR.puts("API server not reachable: #{e.inspect}")
rescue Exception => e
  STDERR.puts("Something unexpected happened: #{e.inspect}")
  STDERR.puts e.backtrace
end

