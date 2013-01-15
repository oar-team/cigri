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

config = Cigri.conf

if config.exists?('RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS')
  DEFAULT_TAP = config.get('RUNNER_DEFAULT_INITIAL_NUMBER_OF_JOBS').to_i
else
  DEFAULT_TAP = 5
end

# TODO: this is maybe something not to be fixed, but computed, and maybe 
# dependent on the campaign, not only the cluster
QUEUE_GAUGE = 10

module Cigri
  ##
  # Meta class for REST Clusters
  # This class defines the interface for cluster objects.
  ##
  class RestCluster
    # description is a hash containing all the fields describing a cluster
    attr_reader :description, :id, :taps

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
        if @description["api_auth_header"].nil? || @description["api_auth_header"]==""
          # Default value for API auth header variable
          @description["api_auth_header"]="X_REMOTE_IDENT" 
        end
        @id = id
        @taps={}
      end

      # Create a rest_client api instance
      @api = RestSession.new(@description,
                             "application/json")
    end

    # Alias to behave like other cigri objects
    def props
      @description.inject({}){|h,(k,v)| h[k.to_sym] = v; h}
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
      events=Cigri::Eventset.new(:where => "state='open' and cluster_id=#{@id} and class='cluster' and code='BLACKLIST'")
      return true if events.length > 0
      if opt[:campaign_id]
        events=Cigri::Eventset.new(:where => "state='open' and cluster_id=#{@id} 
                                   and campaign_id=#{opt[:campaign_id]} 
                                   and class='campaign'
                                   and code='BLACKLIST'")
        return true if events.length > 0
      end
      false
    end

    # Check if the cluster is blacklisted for a campaign, only because it has EXIT_ERROR events
    # This case is special, because the runner doesn't have to stop checking active jobs on such errors
    def blacklisted_because_of_exit_errors?(opt={})
      raise Cigri::Error, "Missing :campaign_id!" if not opt[:campaign_id]
      events=Cigri::Eventset.new(:where => "state='open' and cluster_id=#{@id} 
                                   and campaign_id=#{opt[:campaign_id]} 
                                   and class='campaign'
                                   and code='BLACKLIST'")
      events.each do |event|
        parent_event=Cigri::Event.new(:id => event.props[:parent].to_i)
        return false if parent_event.props[:code] != "EXIT_ERROR"
      end
      true
    end

    # Check if the cluster has some launching jobs
    def has_launching_jobs?
      n=0
      db_connect() do |dbh|
        n=get_cluster_nb_launching_jobs(dbh, @id)
      end
      return n > 0
    end

    # Returns yes if the queue (jobs_to_launch) is under the gauge
    def queue_low?
      n=0
      db_connect() do |dbh|
        n=dbh.select_one("SELECT count(*) 
                        FROM jobs_to_launch 
                        WHERE cluster_id=?",@id)[0].to_i
      end
      return true if n < QUEUE_GAUGE
      CLUSTERLIBLOGGER.debug("Cluster #{name} has #{n} jobs in queue")
      return false
    end

    # Get the running campaigns on this cluster
    def running_campaigns
      result=[]
      db_connect() do |dbh|
        query = "SELECT distinct campaign_id FROM campaign_properties, campaigns 
               WHERE campaigns.id=campaign_properties.campaign_id AND state='in_treatment' 
                   AND cluster_id = ?"
        result=dbh.select_all(query, @id).flatten
      end
      return result unless result.nil?
      return []
    end

    # Check the api connexion
    def check_api?
      begin
        @api.get("")
      rescue => e
        CLUSTERLIBLOGGER.warn("Check function returned error for #{name}: #{e}")
        false
      end
    end     

    # Set a tap
    def set_tap(campaign_id,tap_value)
      @taps[campaign_id]=tap_value
    end

    # Reset/init all the taps
    def reset_taps(value=DEFAULT_TAP)
      campaigns=running_campaigns
      return if campaigns.nil?
      campaigns.each do |campaign_id|
        set_tap(campaign_id,value)
      end
    end

    # Runs a procedure with common exception checks
    # Every rest query call has to be send via this method
    # We raise a Cigri::ClusterAPIConnectionError for errors
    # that are not specific to a campaign. From the runner point
    # of view, whith such an error, it should retry later (ie
    # automatically resubmit a job for example)
    # On the other side, PermissionDenied (401), Forbidden (403) and ServerError (500)
    # are considered campaign problems and should not block the cluster
    # for other campaigns, so we do not generate an open event.
    def secure_run(p,default_error_code)
      begin
        return p.call

      # Exceptions that trig fatal events
      rescue RestClient::RequestTimeout => e
        event=Cigri::Event.new(:class => "cluster", :cluster_id => @id, :code => "TIMEOUT", :message => e)
        Cigri::Colombo.new(event).check
        raise Cigri::ClusterAPIConnectionError, e.message
      rescue Errno::ECONNREFUSED => e
        event=Cigri::Event.new(:class => "cluster", :cluster_id => @id, :code => "CONNECTION_REFUSED", :message => e)
        Cigri::Colombo.new(event).check
        raise Cigri::ClusterAPIConnectionError, e.message
      rescue Errno::ECONNRESET => e
        event=Cigri::Event.new(:class => "cluster", :cluster_id => @id, :code => "CONNECTION_RESET", :message => e)
        Cigri::Colombo.new(event).check
        raise Cigri::ClusterAPIConnectionError, e.message
      rescue OpenSSL::SSL::SSLError => e
        event=Cigri::Event.new(:class => "cluster", :cluster_id => @id, :code => "SSL_ERROR", :message => e)
        Cigri::Colombo.new(event).check
        raise Cigri::ClusterAPIConnectionError, e.message

      # Exceptions that trig logging only events (created in the closed state)
      rescue Cigri::ClusterAPIPermissionDenied => e
        event=Cigri::Event.new(:state => 'closed', :class => "cluster", :cluster_id => @id, :code => "PERMISSION_DENIED", :message => e)
        Cigri::Colombo.new(event).check
        raise
      rescue Cigri::ClusterAPIForbidden => e
        event=Cigri::Event.new(:state => 'closed', :class => "cluster", :cluster_id => @id, :code => "FORBIDDEN", :message => e)
        Cigri::Colombo.new(event).check
        raise
      rescue Cigri::ClusterAPIServerError => e
        event=Cigri::Event.new(:state => 'closed', :class => "cluster", :cluster_id => @id, :code => "CLUSTER_API_SERVER_ERROR", :message => e)
        Cigri::Colombo.new(event).check
        raise

      # Exceptions that should not trig events at this level
      rescue Cigri::ClusterAPINotFound => e
        raise 

      # All other exceptions trig a fatal default event
      rescue => e
        event=Cigri::Event.new(:class => "cluster", :cluster_id => @id, :code => default_error_code, :message => "#{e.class}: #{e}")
        Cigri::Colombo.new(event).check
        raise
      end
    end    

    # Map user if necessary (if an entry is found into users_mapping table)
    def map_user(user)
      nil if user.nil?
      mapped_user=Dataset.new("users_mapping", :where => "grid_login='#{user}' and cluster_id = #{@id}")
      mapped_user.length > 0 ? mapped_user.records[0].props[:cluster_login] : user
    end

    # Return true if the stress_factor is above 1
    def under_stress?
      props[:stress_factor].to_f >= 1
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
    def delete_job(job_id,user)
      raise "Method must be overridden"
    end

    # Get a file
    def get_file(path,user)
      raise "Method must be overridden"
    end

    # Get global stress factor
    def get_global_stress_factor
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
        secure_run proc{ @api.get_collection("jobs/details#{array}") },"GET_JOBS"
      end 
 
      def submit_job(job, user="")
        # Workaround for OAR not taking 1 parameters array jobs
        if job["param_file"] and job["param_file"].lines.count == 1
          job["command"] += " " + job["param_file"]
          job.delete("param_file")         
        end
        #
        secure_run proc{ @api.post("jobs",job, {@description["api_auth_header"] => map_user(user)}) }, "SUBMIT_JOB"
      end
 
      def get_job(job_id, user=nil)
        if (job_id.is_a?(Integer))
          if (user.nil?)
            secure_run proc{ @api.get("jobs/#{job_id}") }, "GET_JOB"
          else
            secure_run proc{ @api.get("jobs/#{job_id}",{@description["api_auth_header"] => map_user(user)}) }, "GET_JOB"
          end
         else
          CLUSTERLIBLOGGER.error("No valid id passed to get_job on #{name}!")
          nil
        end
      end
 
      def delete_job(job_id, user="")
        secure_run proc{ @api.delete("jobs/#{job_id}", {@description["api_auth_header"] => map_user(user)}) }, "DELETE_JOB"
      end
 
      def get_file(path, user=nil,tail=0)
        secure_run proc{ @api.get("media"+path+"?tail="+tail.to_s,{@description["api_auth_header"] => map_user(user)},:raw => true) }, "GET_MEDIA"
      end

      # Get global stress factor
      def get_global_stress_factor
        stress_factor=0.0
        begin
          result=secure_run proc{ @api.get("stress_factor") }, "GET_STRESS_FACTOR"
          stress_factor=result["GLOBAL_STRESS"].to_f
        rescue
          CLUSTERLIBLOGGER.warning("Could not get the stress_factor of #{name}!")
        end
        return stress_factor
      end
 
    end # OARCluster
  
    ##
    # g5k REST API methods definitions
    # Check the RestCluster class for definitions
    ##
    class G5kCluster < RestCluster

      def get_job(job_id, user=nil)
        job = secure_run proc{ @api.get("jobs/#{job_id}") }, "GET_JOB"
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
        params = (job.delete("param_file") || " ").split("\n")
        ids = []
        params.each do |param|
          job["command"] = "#{command} #{param}"
          job["queue"] = "besteffort" if job["type"] == "besteffort"
          id = secure_run proc { @api.post("jobs", job, {@description["api_auth_header"] => map_user(user)})["uid"] }, "SUBMIT_JOB"
          ids << id
        end
        if ids.length == 1
          ids = ids.first.to_i
        end
        {"id" => ids}
      end

      def delete_job(job_id, user)
        secure_run proc { @api.delete("jobs/#{job_id}", {@description["api_auth_header"] => map_user(user)})}, "DELETE_JOB"
      end

      def get_resources
        raise "not yet implemented"      
      end 

      def get_global_stress_factor
        CLUSTERLIBLOGGER.debug("Stress factor not implemented for g5k clusters")
        return 0.0
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
