#!/usr/bin/ruby -w
# 
####################################################################################
# CIGRI Status reporter.
# It updates the "gridstatus" table
# It prints out the resources status of every cluster if $verbose is true
#
# Requirements:
#        ruby1.8 (or greater)
#        libdbi-ruby
#        libdbd-mysql-ruby or libdbd-pg-ruby
#        libyaml-ruby
# ###################################################################################

#####################################################################################
#
# CONFIGURATION
#
#####################################################################################

# You can store the configuration on a separate file or comment out the configuration
# variables below
load "/etc/cigri_rb.conf"

# Database configuration
#$cigri_db = 'cigri'
#$host = 'localhost'
#$login = 'root'
#$passwd = ''

# Verbosity (for debuging purpose)
$verbose = false
$verbose = true

#######################################################################################

require 'dbi'
require 'time'
require 'optparse'
require 'yaml'
require 'pp'

#########################################################################
# Cluster class
#########################################################################
class Cluster
    attr_reader :name, :batch, :unit

    # Creation
    def initialize(name,batch,unit,dbh)
        @name=name
        @batch=batch
        @unit=unit
	@unit="cpu" if (unit == '')
	@dbh=dbh
        query = "SELECT eventType FROM events WHERE eventState='ToFIX' 
	                                        AND eventClusterName='#{@name}'
						AND eventMJobsId is null"
	@sql_status=@dbh.select_all(query)
    end

    # Status of the cluster
    def status
      if not @sql_status.empty?
        return 1
      else
        return nil
      end
    end

    # Status reason
    def status_reason
      if status
        return @sql_status[0]['eventType']
      else
        return nil
      end
    end

    # Printing
    def to_s
        sprintf "Cluster #{@name} -> batch:#{@batch}, unit:#{@unit}"
    end

    # Calculates the maximum resource units this cluster have
    def max_resources
        puts "searching max resources of #{@name}" if $verbose
        query = "SELECT cast(sum(nodeMaxWeight) as unsigned) as max_resources FROM nodes where nodeClusterName='#{@name}'"
	sql_sum=@dbh.select_all(query)
	return sql_sum[0]['max_resources'].to_i || 0
    end

    # Calculates the free resource units this cluster have
    def free_resources
        query = "SELECT cast(sum(nodeFreeWeight) as unsigned) as free_resources FROM nodes where nodeClusterName='#{@name}'"
        sql_sum=@dbh.select_all(query)
        return sql_sum[0]['free_resources'].to_i || 0
    end

    # Claculate the number of resources used by cigri on this cluster
    def used_resources
       query = "SELECT cast(sum(propertiesJobWeight) as unsigned) as count 
                       FROM jobs,properties 
		       WHERE jobClusterName='#{@name}'
                       AND jobState='Running'
		       AND propertiesClusterName='#{@name}'
		       AND propertiesMJobsId=jobMJobsId"
       sql_count=@dbh.select_all(query)
       return sql_count[0]['count'].to_i || 0
    end
end


#########################################################################
# Main
#########################################################################


# Connect to the database
#
def base_connect(dbname_host,login,passwd)
    return DBI.connect("dbi:Mysql:#{dbname_host}",login,passwd)
end

dbh = base_connect("#{$cigri_db}:#{$host}",$login,$passwd)

# Select all the clusters
query = "SELECT * from clusters"
sql_clusters=dbh.select_all(query)
clusters=[]
sql_clusters.each do |sql_cluster|
  cluster=Cluster.new(sql_cluster['clusterName'],sql_cluster['clusterBatch'],sql_cluster['clusterResourceUnit'],dbh)
  clusters << cluster
end

# Updating and printing
total_max=0
total_free=0
total_used=0
n_clusters=0
n_blacklisted=0
timestamp=Time.now.to_i
clusters.each do |cluster|
  n_clusters+=1
  max=cluster.max_resources
  free=cluster.free_resources
  used=cluster.used_resources
  total_max+=max
  total_free+=free
  total_used+=used
  puts cluster.to_s if $verbose
  if cluster.status
    puts "    BLACKLISTED! (#{cluster.status_reason})" if $verbose
    n_blacklisted+=1
  end
  puts "    Max #{cluster.unit}s:  #{max}" if $verbose
  puts "    Free #{cluster.unit}s: #{free}" if $verbose
  puts "    Used by cigri : #{used}" if $verbose
  query = "INSERT INTO gridstatus (timestamp,clusterName,maxResources,freeResources,usedResources)
                                  VALUES
				  ('#{timestamp}','#{cluster.name}','#{max}','#{free}','#{used}')"
  dbh.do(query)  
end
if $verbose
  puts
  puts "TOTAL:"
  puts "    Total clusters: #{n_clusters}"
  puts "    Blacklisted clusters: #{n_blacklisted}"
  puts "    Max resources:  #{total_max}"
  puts "    Free resources: #{total_free}"
  puts "    Used resources: #{total_used}"
end
