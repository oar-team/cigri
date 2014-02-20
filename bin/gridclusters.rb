#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'optparse'
require 'version.rb'

infos = false
more_infos = false

optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} [options]"
  
  opts.on( '--version', 'Display Cigri version' ) do
    puts "#{File.basename(__FILE__)} v#{Cigri::VERSION}"
    exit
  end

  opts.on( '-i', '--infos', 'Show infos about each cluster' ) do
    infos = true
  end

  opts.on( '-I', '--more_infos', 'Show detailed infos about each cluster' ) do
    infos = true
    more_infos = true
  end
  
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts "Shows available clusters"
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

url="/clusters"

begin 
  client = Cigri::Client.new 

  response = client.get(url)
  clusters = JSON.parse(response.body)
  string=""
  clusters['items'].sort_by{|c| c['id']}.each do |item|
    string+=item['id']+": "+item["name"]
    if infos
      response = client.get(url+"/"+item['id'])
      cluster = JSON.parse(response.body)
      if more_infos
        cluster.each_key do |key|
          string+= "\n    "+key+": "+cluster[key].to_s if key != "links" and not cluster[key].nil?
        end
      else
        string+= " ("+cluster['ssh_host']+","+cluster['stress_factor']
        string+=",BLACKLISTED" if cluster['blacklisted']
        string+=")"
      end
    end
    string+="\n"
  end
  puts string
   
rescue Errno::ECONNREFUSED => e
  STDERR.puts("API server not reachable: #{e.inspect}")
rescue Exception => e
  STDERR.puts("Something unexpected happened: #{e.inspect}")
  STDERR.puts e.backtrace
end

