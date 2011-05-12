#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../', 'lib'))
$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'
require 'cigri-clusterlib'

cluster=Cigri::Cluster.new(:name => "fukushima")
job=cluster.submit_job(:command => "sleep 300")
puts job["id"]

puts "Job deleted" if cluster.delete_job(job["id"])

state=cluster.get_job(job["id"])["state"]
while state != "Terminated" && state != "Error" do
  state=cluster.get_job(job["id"])["state"]
  puts "Job is still #{state}..."
  sleep(1)
end
puts "Ended; final state: #{state}"

#cluster.get_resources.each do |resource|
#  puts resource['id'].to_s+" ("+resource['network_address']+" on "+resource['cluster']+")"
#  resource.jobs.each do |job|
#    puts "  job: "+job['id'].to_s
#  end
#end

