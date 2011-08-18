#!/usr/bin/ruby -w

$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'
require 'json'
require 'net/http'
require 'optparse'

username = nil
optparse = OptionParser.new do |opts|
  opts.banner = 'Usage: gridstat [options] ...'
  opts.version = "v#{Cigri::VERSION}"
  
  opts.on( '-u', '--username USERNAME', String, 'Only print campaigns from USERNAME' ) do |u|
    username = u
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

campaigns = JSON.parse(Net::HTTP.get('localhost', '/campaigns', 9292))['items']

if username
  campaigns.reject!{|h| h['user'].nil? || h['user'] != username}
end

campaigns.each do |campaign|
  pp campaign
end
