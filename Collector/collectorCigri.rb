#!/usr/bin/ruby -w
# COLLECTOR FOR CIGRI
# The collector shortcuts the normal cigri ssh mechanism as it makes a
# pipe through ssh but it checks SSH connexion before collecting each
# cluster.

##################################################################################
# CONFIGURATION AND INCLUDES LOADING
##################################################################################
if ENV['CIGRIDIR']
  require ENV['CIGRIDIR']+'/ConfLib/conflibCigri.rb'
else
  require File.dirname($0)+'/../ConfLib/conflibCigri.rb'
end
$:.replace([get_conf("INSTALL_PATH")+"/Iolib/"] | $:)

require 'dbi'
require 'time'
require 'fileutils'
require 'ftools'
require 'open4'
require 'cigriJobs'
require 'cigriUtils'
require 'cigriEvents'

$verbose = false
#$verbose = true
$tag="[COLLECTOR]   "

if get_conf("RESULTS_DIR")
  $results_dir=get_conf("RESULTS_DIR")
else
  $results_dir="/home/cigri/results/"
end

if get_conf("SSH_CMD")
  $ssh_cmd=get_conf("SSH_CMD")
else
  $ssh_cmd="ssh"
end

if not File.directory?($results_dir)
  puts $tag+"Results directory "+$results_dir+" not found!"
  exit 1
end

#########################################################################
# FUNCTIONS
#########################################################################

# Check ssh on a cluster using CiGri Net library
def check_ssh(cluster)
  puts "#{$tag}Checking SSH on cluster #{cluster}"
  return system(File.dirname($0)+"/../Net/SSHcheck.pl",cluster)
end

# Get files into a local archive
def get_files(cluster,execdir,files,archive)
  # Make the archive directory if it does not exists
  archive_dir=File::dirname(archive)
  File::makedirs(archive_dir) unless File::directory?(archive_dir)
  # Construct the ssh pipe
  files=files.collect { |f| f="\"#{f}\"" }
  find_cmd="find . -maxdepth 1 -name "+files.join(" -o -name ")
  cmd="#{$ssh_cmd} #{cluster} 'cd #{execdir} || exit 100 && files=`#{find_cmd}`;test \"$files\" || exit 101 && tar cf - $files|gzip -c -; [ ${PIPESTATUS[0]} = 0 ] || exit 102' > #{archive}.tgz"
  puts "#{$tag} #{archive}.tgz"
  puts "#{$tag}   Sending command: #{cmd}" if $verbose
  # Send the command
  stdout,stderr,status=shell_cmd(cmd)
  # Check the status and create events if necessary
  if status != 0
    if status  == 100
      puts "#{$tag}  Warning: could not go into #{execdir} "
    elsif status  == 101
      puts "#{$tag}  Warning: "+files.join(',')+" not found"
    elsif status  == 102
      puts "#{$tag}  ERROR with tar: "+stderr
      add_new_cluster_event($dbh,cluster,0,"COLLECTOR","ERROR with tar: "+stderr)
      return false
    else
      puts "#{$tag}  Unknown ERROR collecting "+files.join(',')+": "+stderr
      add_new_cluster_event($dbh,cluster,0,"COLLECTOR","Unknown ERROR collecting "+files.join(',')+": "+stderr)
      return false
    end
  end
  return true
end

# Remove the files from a remote cluster
def remove_files(cluster,execdir,files,user)
  files=files.collect { |f| f="#{execdir}/#{f}" }
  if files.empty? || execdir == ""
    puts "#{$tag}  Warning: no files to remove"
    return false
  end
  cmd="#{$ssh_cmd} #{cluster} 'sudo -u #{user} rm -rf "+files.join(" ")+"'"
  puts "#{$tag}   Removing "+files.join(" ") if $verbose
  stdout,stderr,status=shell_cmd(cmd)
  if status != 0
    puts "#{$tag}  Warning: error while removing files: "+stderr
  end
  # maybe we should do more error checking here...
  return true
end

#########################################################################
# MAIN
#########################################################################

puts "#{$tag}Starting"

# Connect to database
$dbh = db_init()

# Lock
trap(0) { 
  puts "#{$tag}Unlocking collector"
  unlock_collector($dbh)
  puts "#{$tag}Ending"
}
lock_collector($dbh,43200)

collect_id={}
clusters={}

# Get the jobs to collect
tocollectJobs=tocollect_Jobs($dbh)
tocollectJobs.remove_blacklisted

# For each job to collect
tocollectJobs.each do |job|
  files=[]
  # For a Mjob, create a new collect id
  if collect_id[job.mjobid].to_i == 0
    collect_id[job.mjobid]=new_collect_id($dbh,job.mjobid)
    puts "#{$tag}Collecting #{job.mjobid} - # #{collect_id[job.mjobid]}"
  end
  # Construct the archive directory name
  repository="#{$results_dir}/#{job.user}/#{job.mjobid}/#{collect_id[job.mjobid]}/#{job.cluster}/#{job.jid}"
  if job.execdir == "~"
    job.execdir = "~#{job.localuser}"
  end
  # Construct the list of files to fetch
  if job.name.to_s != ""
    files << "#{job.name}"
  end
  if job.batchtype.to_s == "OAR2"
    files << "OAR*.#{job.batchid}.stderr"
    files << "OAR*.#{job.batchid}.stdout"
  else
    puts "#{$tag}Warning: #{job.batchtype} batch type files not collected"
  end
  # On the first job of a cluster, check ssh connexion
  if clusters[job.cluster].nil?
    if not check_ssh(job.cluster)
      # Blacklisting of the cluster because of a SSH problem
      add_new_cluster_event($dbh,job.cluster,0,"SSH","SSH event from the collector")
      clusters[job.cluster]="blacklisted"
    else
      clusters[job.cluster]="ok"
    end
  end
  # If the cluster has not been blacklisted...
  if clusters[job.cluster] == "ok"
    # get the files
    if not get_files(job.cluster,job.execdir,files,repository)
      clusters[job.cluster] = "blacklisted"
      puts "#{$tag}Cluster #{job.cluster} is blacklisted"
    # delete the files from the cluster
    else 
      if not FileTest.zero?("#{repository}.tgz") 
       remove_files(job.cluster,job.execdir,files,job.user)
      else 
        puts "#{$tag}  Warning: empty archive, so not removing files."
      end
      # Mark the job as collected
      set_collected_job($dbh,job.jid,collect_id[job.mjobid])
    end
  end
end

