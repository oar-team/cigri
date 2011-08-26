#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-conflib'
require 'json'
require 'net/http'
require 'optparse'
require 'version.rb'
require 'pp'

jsons = []
details = false
optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} <-j JDL | -f JDL_FILE> [options]"
  
  opts.on( '-d', '--details', 'Prints all the JSON of the campaign instead of just the ID' ) do
    details = true
  end
  
  opts.on( '-f', '--file JDL_FILE', 'JDL File containing the JSON' ) do |file|
    jsons << File.read(file)
  end
  
  opts.on( '-j', '--json JSON', 'JSON String' ) do |json|
    jsons << json
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

def submit_campaign(jdl)
  conf = Cigri::Conf.new('/etc/cigri-api.conf')
  http = Net::HTTP.new(conf.get('API_HOST'), conf.get('API_PORT'))
  http.read_timeout = conf.get('API_TIMEOUT') if conf.exists?('API_TIMEOUT')
  
  http.post("/campaigns", jdl, 'Content-Type' => 'application/json') 
end

STDERR.puts "Please provide at least one JSON or JDL_FILE" if jsons.length == 0

begin
  jsons.each do |json|
    response = submit_campaign(json)
    if response.code != "201"
      STDERR.puts("Error submitting campaign: #{response.body}")
    else
      if details
        puts response.body
      else
        puts JSON.parse(response.body)['id']
      end
    end
  end
rescue Errno::ECONNREFUSED => e
  STDERR.puts("API server not reachable: #{e.inspect}")
rescue Exception => e
  STDERR.puts("Something unexpected happened: #{e.inspect}")
end

