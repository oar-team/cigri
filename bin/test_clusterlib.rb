#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../', 'lib'))
$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'
require 'cigri-clusterlib'

cluster=Cigri::Cluster.new(:name => "tchernobyl")
cluster.get_resources.each do |resource|
  puts resource['id']
end

