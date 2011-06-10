#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../', 'lib'))
$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'
require 'cigri-joblib'

j=Cigri::Job.new(:campaign_id => 1, :state => "running", :name => "obiwan1")
#job=Cigri::Job.new(:id => 29)
#puts job.to_s

jobs=Cigri::Campaignset.new
jobs.get_running
jobs.each do |job|
  puts "Campaign #{job.id}"
  job.get_clusters
#  pp job.clusters
end

jobs=Cigri::JobtolaunchSet.new
jobs.get_next(3,5)
jobs.each do |job|
  puts job
end

j.delete

