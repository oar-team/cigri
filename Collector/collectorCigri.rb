#!/usr/bin/ruby -w
# 

#####################################################################################
#
# CONFIGURATION
#
#####################################################################################

# You can store the configuration on a separate file or comment out the configuration
# variables below
if ENV['CIGRIDIR']
then
  load "#{ENV['CIGRIDIR']}/cigri_rb.conf"
else
  load "/etc/cigri_rb.conf"
end
if not defined? $results_dir
  $results_dir='/home/cigri/results'
end

# Database configuration
#$cigri_db = 'cigri'
#$host = 'localhost'
#$login = 'root'
#$passwd = ''

# Size of the window in seconds on wich the job throughput is calculated
# time_window_size = 3600

# Verbosity (for debuging purpose)
#$verbose = false
$verbose = true

#######################################################################################
# Includes loading
#######################################################################################

$:.replace([$iolib_dir] | $:)

require 'dbi'
require 'time'
#require 'optparse'
#require 'yaml'
#require 'pp'
require 'fileutils'
require 'ftools'

require 'cigriJobs'
#require 'cigriClusters'
require 'cigriUtils'

$tag="[COLLECTOR]   "

#########################################################################
# FUNTCIONS
#########################################################################
def get_files(cluster,execdir,files,archive)
  archive_dir=File::dirname(archive)
  File::makedirs(archive_dir) unless File::directory?(archive_dir)
  files=files.collect { |f| f="\"#{f}\"" }
  find_cmd="find . -maxdepth 1 -name "+files.join(" -o -name ")
  cmd="ssh #{cluster} 'cd #{execdir} && files=`#{find_cmd}`;test \"$files\" || exit 0 && tar cf - $files|gzip -c -; exit ${PIPESTATUS[0]}' > #{archive}.tgz"
  puts "#{$tag} #{archive}.tgz"
  if not system(cmd)
    puts "#{$tag}ERROR collecting #{cluster}:"+files.join+" into #{archive}.tgz"
    # TODO
    # Add an event and blacklist the cluster
  else 
    # TODO
    # - Remove the files on the cluster
    # - Mark the job as collected into database
  end
end

#########################################################################
# MAIN
#########################################################################

# Connect to database
dbh = base_connect("#{$cigri_db}:#{$host}",$login,$passwd)

# Lock
trap(0) { unlock_collector(dbh)
          puts "#{$tag}Unlocking collector" if $verbose }
lock_collector(dbh,43200)

#cluster=Cluster.new(dbh,"zephir.mirage.ujf-grenoble.fr")
#if cluster.active?(415)
#  puts "ACTIVE"
#end

collect_id={}
tocollectJobs=tocollect_Jobs(dbh)
tocollectJobs.remove_blacklisted
tocollectJobs.each do |job|
  files=[]
  if collect_id[job.mjobid].to_i == 0
    collect_id[job.mjobid]=new_collect_id(dbh,job.mjobid)
    puts "#{$tag}Collecting #{job.mjobid} - # #{collect_id[job.mjobid]}"
  end
  repository="#{$results_dir}/#{job.user}/#{job.mjobid}/#{collect_id[job.mjobid]}/#{job.cluster}/#{job.jid}"
  if job.execdir == "~"
    job.execdir = "~#{job.localuser}"
  end
  if job.name.to_s != ""
    files << "#{job.name}"
  end
  if job.batchtype.to_s == "OAR2"
    files << "OAR*.#{job.batchid}.stderr"
    files << "OAR*.#{job.batchid}.stdout"
  else
    puts "#{$tag}Warning: #{job.batchtype} batch type files not collected"
  end
  get_files(job.cluster,job.execdir,files,repository)
end

