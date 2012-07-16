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
require 'cigri-eventlib'

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
            raise Cigri::Error.new("At least :id or :name should be passed to RestCluster constructor!", CLUSTERLIBLOGGER)
          else
            id = get_cluster_id(dbh,name)
            raise Cigri::Error.new("No cluster found by that name: #{name}", CLUSTERLIBLOGGER) if id.nil?
          end
        end
        @description = get_cluster(dbh, id)
        if @description["api_auth_header"].nil?
          # Default value for API auth header variable
          @description["api_auth_header"]="X_REMOTE_IDENT" 
        end
        @id = id
      end

      # Create a rest_client api instance
      @api = RestSession.new(@description,
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

    # Check if the cluster is blacklisted
    # It may be a check for a campaign blacklist only if :campaign_id is given
    def blacklisted?(opt={})
      events=Cigri::Eventset.new(:where => "state='open' and cluster_id=#{@id} and class='cluster'")
      return true if events.length > 0
      if opt[:campaign_id]
        events=Cigri::Eventset.new(:where => "state='open' and cluster_id=#{@id} 
                                   and campaign_id=#{opt[:campaign_id]} 
                                   and class='campaign'")
        return true if events.length > 0
      end
      false
    end

    # Check if the cluster has some launching jobs
    def has_launching_jobs?
      n=0
      db_connect() do |dbh|
        n=get_cluster_nb_launching_jobs(dbh, @id)
      end
      return n > 0
    end

    # Get the resources
    def get_resources
      raise "Method must be overridden"
    end

    # Get the running jobs
    def get_jobs
      raise "Method must be overridden"
    end
    
    # Submit the given job for the given user
    def submit_job(job,user)
      raise "Method must be overridden"
    end

    # Delete the given job
    def delete_job(job_id)
      raise "Method must be overridden"
    end

  end # RestCluster


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
 
      def submit_job(job, user="")
        begin
          @api.post("jobs",job, {@description["api_auth_header"] => user})
        rescue => e
          Cigri::Event.new(:class => "cluster", :cluster_id => @id, :code => "SUBMIT_JOB", :message => e)
          raise
        end
      end
 
      def get_job(job_id, user=nil)
        if (job_id.is_a?(Integer))
          if (user.nil?)
            @api.get("jobs/#{job_id}")
          else
            @api.get("jobs/#{job_id}",{@description["api_auth_header"] => user})
          end
        else
          CLUSTERLIBLOGGER.error("No valid id passed to get_job on #{name}!")
          nil
        end
           # TODO: manage event (cluster blacklist) if timeout
      end
 
      def delete_job(job_id, user="")
        @api.delete("jobs/#{job_id}", {@description["api_auth_header"] => user})
           # TODO: manage event (cluster blacklist) if timeout
      end
  
    end # OARCluster
 
 
  
    ##
    # g5k REST API methods definitions
    # Check the RestCluster class for definitions
    ##
    class G5kCluster < RestCluster

      def get_job(job_id, user=nil)
        job = @api.get("jobs/#{job_id}")
        job["id"] = job["uid"]
        job
      end

      # Get the running jobs
      def get_jobs(props = {})
        res = []
        props[:array].each do |job_id|
          res << self.get_job(job_id)
        end
        res
      end

      # G5K API does not support job arrays, so we split in several calls.
      def submit_job(job, user)
        command = job["command"]
        params = job.delete("param_file").split("\n")
        ids = []
        params.each do |param|
          job ["command"] = "#{command} #{param}"
          ids << @api.post("jobs", job, {@description["api_auth_header"] => user})["uid"]
        end
        {"id" => ids}
      end

      def delete_job(job_id, user)
        @api.delete("jobs/#{job_id}", {@description["api_auth_header"] => user})
      end

      def get_resources
        raise "not yet implemented"      
      end 
    end # G5kCluster



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
      db_connect() do |dbh|
        return get_available_api_types(dbh)
      end
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
        raise Cigri::Error.new("#{type} is not listed into the available_types!", CLUSTERLIBLOGGER)
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

  end # Cluster

  ##
  # Class for operations on a set of clusters
  ##
  class ClusterSet < Array

    # A cluster set is an array of cluster selected from the DB
    def initialize(where_clause=nil)
      db_connect() do |dbh|
        clusters = select_clusters(dbh, where_clause)
        if clusters
          select_clusters(dbh, where_clause).each do |id|
            push Cluster.new(:id => id)
          end
        end
      end
    end

    def remove_blacklisted
      # TODO
    end

  end # ClusterSet

end
