#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri-clusterlib'

abort("Usage: #{File.basename(__FILE__)} <name> <api_url> <api_auth_type(cert|password)> <api_username> <api_password> <ssh_host> <batch> <resource_unit> <power> <properties>") unless ARGV.length == 10

# Check the batch type
available_batch_types = Cigri::Cluster.available_types
unless available_batch_types.include?(ARGV[6])
  raise "\"#{ARGV[6]}\" is not a valid batch system type. Valid types are: #{available_batch_types.join(', ')}"
end

db_connect() do |dbh|
  new_cluster(dbh, *ARGV)
end
