#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri-clusterlib'

abort("Usage: #{File.basename(__FILE__)} <name> <api_url> <api_username> <api_password> <ssh_host> <batch> <resource_unit> <power> <properties>") unless ARGV.length == 9

# Check the batch type
available_batch_types = Cigri::Cluster.available_types
unless available_batch_types.include?(ARGV[5])
  raise "\"#{ARGV[5]}\" is not a valid batch system type. Valid types are: #{available_batch_types.join(', ')}"
end

db_connect() do |dbh|
  new_cluster(dbh, *ARGV)
end
