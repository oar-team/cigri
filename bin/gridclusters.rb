#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'optparse'
require 'version.rb'

infos = false
more_infos = false
usage = false
bars = false

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

  opts.on( '-u', '--usage', 'Show usage infos about each cluster (implies -i)' ) do
    infos = true
    usage = true
  end

  opts.on( '-b', '--bars', 'Show usage infos with colored bars (implies -i -u)' ) do
    infos = true
    usage = true
    bars = true
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
  if usage
    response = client.get("/gridusage")
    usage_values = JSON.parse(response.body)['items'][0]['clusters']
  end 
  string=""
  clusters['items'].sort_by{|c| c['id']}.each do |item|
    name=item['id']+": "+item["name"]
    string+=name
    if infos
      response = client.get(url+"/"+item['id'])
      cluster = JSON.parse(response.body)
      if more_infos
        cluster.each_key do |key|
          string+= "\n    "+key+": "+cluster[key].to_s if key != "links" and not cluster[key].nil?
        end
      else
        string+= " , "+cluster['ssh_host']+" (stress:"+cluster['stress_factor']
        string+=", BLACKLISTED" if cluster['blacklisted']
        string+=", UNDER_STRESS" if cluster['under_stress']
        string+=")"
      end
      if usage
        cluster_usage=usage_values.select{|u| u["cluster_name"]==item["name"]}
        if not cluster_usage[0].nil? and not cluster['blacklisted']
          if bars
            size=80
            unavailable=cluster_usage[0]["unavailable_resources"]
            used=cluster_usage[0]["used_resources"]
            cigri=cluster_usage[0]["used_by_cigri"]
            used=used-cigri
            max=cluster_usage[0]["max_resources"]
            free=max - cigri - used - unavailable
            string+=" (#{max} resources)\n"
            (unavailable*size/max).round.to_i.times do
              string+="\033[41m \033[0m" # red
            end
            (used*size/max).round.to_i.times do
              string+="\033[43m \033[0m" # yellow
            end
            (cigri*size/max).round.to_i.times do
              string+="\033[47m \033[0m" # white
            end
            (free*size/max).round.to_i.times do
              string+="\033[42m \033[0m" # green
            end
            string+="\n"
          else
            cluster_usage[0].each_key do |k|
              string+="\n    "+k+": "+cluster_usage[0][k].to_s if k != "cluster_id" and k != "cluster_name"
            end
          end
        else
          string+="\n    Data temporarily unavailable"
        end
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

