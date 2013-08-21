#!/usr/bin/ruby -w

require 'optparse'
require 'etc'

login = Etc.getlogin
if login != "cigri" && login != "root"
  STDERR.puts "This script must be run as the cigri or root user!"
  exit 1
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../', 'lib'))
$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'
require 'cigri-clusterlib'

clustername=nil
jobfile=nil
user=nil

optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} -c <clustername> -f <jobfile> -u <username>"

  opts.on( '-c NAME', '--cluster', 'Cluster name (as in cigri DB)' ) do |name|
    clustername = name
  end

  opts.on( '-f FILE', '--file', 'Get job description from a file containing a ruby hash definition' ) do |file|
    jobfile = file
  end

  opts.on( '-u USER', '--user', 'Run the job as user' ) do |username|
    user = username
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

begin
  optparse.parse!(ARGV)
rescue OptionParser::ParseError => e
  STDERR.puts e
  STDERR.puts "\n" + optparse.to_s
  exit 1
end

if clustername.nil? || jobfile.nil? || user.nil?
  STDERR.puts optparse.to_s
  exit 1
end


cluster=Cigri::Cluster.new(:name => clustername)

job=eval(File.read(jobfile))

j=cluster.submit_job(j,user)
puts "Id: #{job['id']}"

state=cluster.get_job(job["id"])["state"]

puts "State: #{state}"
