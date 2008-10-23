#!/usr/bin/ruby -w
# COLLECTOR FOR CIGRI

##################################################################################
# CONFIGURATION AND INCLUDES LOADING
##################################################################################
if ENV['CIGRIDIR']
  require ENV['CIGRIDIR']+'/ConfLib/cigriConflib.rb'
else
  require File.dirname($0)+'/../ConfLib/cigriConflib.rb'
end
$:.replace([get_conf("INSTALL_PATH")+"/Iolib/"] | $:)

require 'dbi'
require 'time'
require 'fileutils'
require 'ftools'
require 'cigriJobs'
require 'cigriUtils'

#$verbose = false
$verbose = true
$tag="[COLLECTOR]   "

if get_conf("RESULTS_DIR")
  $results_dir=get_conf("RESULTS_DIR")
else
  $results_dir="/home/cigri/results/"
end

if not File.directory?($results_dir)
  puts $tag+"Results directory "+$results_dir+" not found!"
  exit 1
end

#########################################################################
# FUNCTIONS
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
dbh = db_init()

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

