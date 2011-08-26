#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-conflib'
require 'json'
require 'net/http'
require 'optparse'
require 'version.rb'
require 'pp'

verbose = false
optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} <CAMPAIGN_ID> [CAMPAIGN_IDS...] [options]"
  
  opts.on('-v', '--verbose', 'Be verbose') do
    verbose = true
  end
  
  opts.on( '-V', '--version', 'Display Cigri version' ) do
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

conf = Cigri::Conf.new('/etc/cigri-api.conf')
http = Net::HTTP.new(conf.get('API_HOST'), conf.get('API_PORT'))

ARGV.each do |campaign_id|
  request = Net::HTTP::Delete.new("/campaigns/#{campaign_id}")
  response = http.request(request)
  parsed_response = JSON.parse(response.body)
  if response.code != "202"
    STDERR.puts("Failed to cancel campaign #{campaign_id}: #{parsed_response['message']}.")
  else
    puts "#{parsed_response['message']}." if verbose
  end
end

