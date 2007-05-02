#!/usr/bin/ruby -w
# 
####################################################################################
# CIGRI Status reporter.
# It prints out the resources status of every cluster
#
# Output: in YAML format
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
        query = "SELECT sum(nodeMaxWeight) as max_resources FROM nodes where nodeClusterName='{@name}'"
	sql_sum=@dbh.select_all(query)
	return sql_sum[0]['max_resources']
    end

    # Calculates the free resource units this cluster have
    def free_resources
        query = "SELECT sum(nodeFreeWeight) as free_resources FROM nodes where nodeClusterName='#{@name}'"
        sql_sum=@dbh.select_all(query)
        return sql_sum[0]['free_resources']
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

# Printing
clusters.each do |cluster|
  puts cluster.to_s
  puts "    BLACKLISTED! (#{cluster.status_reason})" if cluster.status
  puts "    Free #{cluster.unit}s: #{cluster.free_resources}"
end


