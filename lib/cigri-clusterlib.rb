#!/usr/bin/ruby -w
#
# Cigri cluster library. This library gives methods to access
# to the local resource manager of the clusters. It is based on
# REST calls.
#
# == Example:
#  cluster=Cigri::Cluster.new(:name => "pode")
#  cluster.get_resources.each do |resource|
#    puts resource['id']
#  end

require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-iolib'
require 'cigri-restclientlib'

CLUSTERLIBLOGGER = Cigri::Logger.new('CLUSTERLIB', CONF.get('LOG_FILE'))

module Cigri
  ##
  # Meta class for REST Clusters
  # This class defines the interface for cluster objects.
  ##
  class RestCluster
    # description is a hash containing all the fields describing a cluster
    attr_reader :description, :id

    ##
    # Creates a new restcluster object, getting it by its id or its name
    # == Parameters
    # A hash containing :id or :name
    # - :id : id of the cluster
    # - :name : name of the cluster
    ##
    def initialize(opts = {})

      # Get the cluster from database
      db_connect() do |dbh|
        if not id = opts[:id]
          if not name = opts[:name]
            raise Cigri::Exception.new("At least :id or :name should be passed to RestCluster constructor!", CLUSTERLIBLOGGER)
          else
            id = get_cluster_id(dbh,name)
            raise Cigri::Exception.new("No cluster found by that name: #{name}", CLUSTERLIBLOGGER) if id.nil?
          end
        end
        @description = get_cluster(dbh, id)
        @id = id
      end

      # Create a rest_client api instance
      @api = RestSession.new(@description["api_url"], 
                             @description["api_username"],
                             @description["api_password"],
                             "application/json")
    end
  
    ##
    # Parse the properties of the cluster if any
    # == returns
    #  - an array of { property => value }
    #  - or nil if no property is available
    ##
    def parse_properties
      if @description["properties"]
        res = {}
        properties = @description["properties"].split(/\s*and\s*/i)
        properties.each do |property|
          ( key, value ) = property.split(/\s*=\s*/)
          res[key] = value.delete("'\"")
        end
        return res
      end
      nil
    end

    # name of a cluster
    def name
      @description["name"]
    end

    # Get the resources
    def get_resources
      raise "Method must be overridden"
    end

    # Get the running jobs
    def get_jobs
      raise "Method must be overridden"
    end
    
    # Submit the given job
    def submit_job(job)
      raise "Method must be overridden"
    end

    # Delete the given job
    def delete_job(job_id)
      raise "Method must be overridden"
    end

  end


  ##
  # Cluster object factory
  # This class allows us to create cluster objects of the 
  # type given by the "batch" field.
  # 
  # == Example: 
  #  cluster=Cigri::Cluster.new(:name => "pode")
  #  Assuming the cluster which name is "pode" is of the type oar2_5, 
  #  this will return a OarCluster object.
  ##
  class Cluster 



   ##
   # Oar REST API methods definitions.
   # Check the RestCluster class for definitions
   ##
   class OarCluster < RestCluster

     def get_resources
       # Get the resources from the api
       resources = @api.get_collection("resources/full")
       # TODO: manage event (cluster blacklist) if timeout
       # Filter the resources depending on cluster properties
       properties = parse_properties
       return resources unless properties
       res = []
       resources.each do |resource|
         not_found = 0
         properties.each_pair do |key,value|
           not_found = 1 if resource[key] != value
         end
         res << resource unless not_found == 1
       end
       res
     end
     
     def get_jobs(props={})
       array="?array=#{props[:array]}" if props[:array]
       @api.get_collection("jobs/details#{array}")
          # TODO: manage event (cluster blacklist) if timeout
     end 

     def submit_job(job)
       @api.post("jobs",job)
          # TODO: manage event (cluster blacklist) if timeout
     end

     def get_job(job_id)
       @api.get("jobs/#{job_id}")
          # TODO: manage event (cluster blacklist) if timeout
     end

     def delete_job(job_id)
       @api.delete("jobs/#{job_id}")
          # TODO: manage event (cluster blacklist) if timeout
     end
 
   end


 
   ##
   # g5k REST API methods definitions
   # Check the RestCluster class for definitions
   ##
   class G5kCluster < RestCluster

     def get_resources
       raise "not yet implemented"      
     end 

     def submit_job(job)
       raise "not yet implemented"      
     end
   end



   ##
   # Lists the available batch types
   #
   # Those types are the only allowed into the batch field of the clusters table.
   # Each of these types correspond to a Class that defines the methods to access
   # to the cluster using the corresponding REST API.
   # Currently, here are the supported types and corresponding classes:
   # - oar2_5 : OarCluster
   # - g5k : G5kCluster
   # All the classes have to implement the methods listed into the RestCluster class.
   #
   ##
   def self.available_types
     ["oar2_5","g5k"]
   end
   
   ##
   # Switch to create objects of the correct type
   #
   # See RestCluster.new() for usage
   ##
   def Cluster::new(opts)
     tmp_cluster = RestCluster.new(opts)
     type = tmp_cluster.description["batch"]
     if not available_types.include?(type)
       raise Cigri::Exception.new("#{type} is not listed into the available_types!", CLUSTERLIBLOGGER)
     end
     classe = 
       case type
         when /oar2_5/
           OarCluster
         when /g5k/
           G5kCluster
       end
     classe::new(opts)
   end

  end

  ##
  # Class for operations on a set of clusters
  ##
  class ClusterSet < Array

    # A cluster set is an array of cluster selected from the DB
    def initialize(where_clause=nil)
      db_connect() do |dbh|
        select_clusters(dbh,where_clause).each do |id|
          push Cluster.new(:id => id)
        end
      end
    end

    def remove_blacklisted
      # TODO
    end

  end

end
