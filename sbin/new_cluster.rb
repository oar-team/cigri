#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri-clusterlib'
# require 'optparse'


# types = []
# db_connect() do |dbh|
#   types = get_available_api_types(dbh)
# end

# optparse = OptionParser.new do |opts|
#   opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

#   opts.on('-b', '--batch API_TYPE', types, "Type of the API (#{types.join(', ')})") do |name|

#   end

#   opts.on('-n', '--name NAME', String, 'Cluster name') do |name|

#   end
  
#   opts.on('-u', '--url API_URL', String, 'URL of the cluster API') do |url|

#   end

#   opts.on('-U', '--user API_USER', String, 'Root user of the API') do |user|

#   end

#   opts.on('-p', '--password API_PASSWORD', String, 'Password of the root user of the API') do |user|

#   end

#   opts.on('-v', '--version', 'Display Cigri version' ) do
#     puts "#{File.basename(__FILE__)} v#{Cigri::VERSION}"
#     exit
#   end
  
#   opts.on( '-h', '--help', 'Display this screen' ) do
#     puts opts
#     exit
#   end
# end

# begin
#   optparse.parse!(ARGV)
# rescue OptionParser::ParseError => e
#   $stderr.puts e
#   $stderr.puts "\n" + optparse.to_s
#   exit 1
# end

# exit


abort("Usage: #{File.basename(__FILE__)} <name> <api_url> <api_auth_type(cert|password)> <api_username> <api_password> <api_auth_header> <ssh_host> <batch> <resource_unit> <power> <properties>") unless ARGV.length == 11

# Check the batch type
available_batch_types = Cigri::Cluster.available_types
unless available_batch_types.include?(ARGV[7])
  raise "\"#{ARGV[7]}\" is not a valid batch system type. Valid types are: #{available_batch_types.join(', ')}"
end

db_connect() do |dbh|
  new_cluster(dbh, *ARGV)
end
