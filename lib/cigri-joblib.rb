#!/usr/bin/ruby -w
#
# This library contains the classes relative to Jobs
# It may be considered as an extension to the iolib, as
# it still makes SQL queries, but more in a "meta" way
#

require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-iolib'
require 'cigri-clusterlib'

CONF = Cigri.conf unless defined? CONF
JOBLIBLOGGER = Cigri::Logger.new('JOBLIB', CONF.get('LOG_FILE'))

module Cigri

  # Job class
  # A Job instance can be get from the database or newly created
  # See Datarecord class for more doc
  class Job < Datarecord
    attr_reader :props

    # Creates a new job or get it from the database
    def initialize(props={})
      super("jobs",props)
    end

  end # class Job

  # Jobset class
  # Example: 
  #  jobs=Cigri::Jobset.new(:where => "name like 'obiwan%'")
  #  jobs=Cigri::Jobset.new
  #  jobs.get_running
  # The jobset class is composed of a join between 3 classes: jobs, parameters and campaigns
  class Jobset < Dataset

    # Creates the new jobset
    def initialize(props={})
      @fields="jobs.id as id, parameters.param as param, campaigns.grid_user as grid_user,
               parameters.campaign_id as campaign_id, param_id, batch_id, cluster_id, 
               collect_id, jobs.state as state, return_code, 
               jobs.submission_time as submission_time, start_time, 
               stop_time, node_name, resources_used, remote_id"
      @join="jobs.param_id=parameters.id and jobs.campaign_id=campaigns.id"
      if (not props[:where].nil?)
        props[:where]+=" and #{@join}"
        if (props[:what].nil?)
          props[:what]=@fields
        end
      end
      super("jobs,parameters,campaigns",props)
    end

    # Alias to the dataset records
    def jobs
      @records
    end

    # Fill the jobset with the currently running jobs
    def get_running(cluster_id=nil)
      cluster_query=""
      if not cluster_id.nil?
        cluster_query="and cluster_id=#{cluster_id}"
      end
      fill(get("jobs,parameters,campaigns",@fields,"jobs.state = 'running' and #{@join} #{cluster_query}"))
    end

    # Get jobs that have just been submitted on cluster_id
    def get_submitted(cluster_id)
      fill(get("jobs,parameters,campaigns",@fields,"
                    (jobs.state = 'submitted' or jobs.state = 'remote_waiting') 
                      and #{@join}
                      and cluster_id=#{cluster_id}"))
    end

    # Get the ids (array) of all campaigns from this jobset
    def campaigns
      campaigns={}
      @records.each do |job|
        campaigns[job.props[:campaign_id]]=1
      end
      return campaigns.keys
    end

    # Submit a set of jobs, using OAR array jobs if possible
    # So, group the jobs by campaigns as only jobs from a
    # same campaign can be launched in the same array
    def submit(cluster_id)
      cluster=Cluster.new(:id => cluster_id)
      self.campaigns.each do |campaign_id|
        campaign=Campaign.new(:id => campaign_id)
        campaign.get_clusters
        jobs=@records.select {|job| job.props[:campaign_id] == campaign_id}
        params=jobs.collect {|job| job.props[:param]}
        submission = {
                       "param_file" => params.join("\n"),
                       "resources" => campaign.clusters[cluster_id]["resources"],
                       "command" => campaign.clusters[cluster_id]["exec_file"]
                       #"properties" => campaign.props[:properties],
                       #"directory" => campaign.props[:exec_dir]
                     }
        # TODO: add walltime, manage grouping,etc...
        JOBLIBLOGGER.info("Submitting new array job on #{cluster.description["name"]} with #{params.length} parameter(s).")
        j=cluster.submit_job(submission,campaign.props[:grid_user])
        if j.nil?
          JOBLIBLOGGER.error("Unhandled error when submitting jobs on #{cluster.description["name"]}!")
        else
          array_jobs << j["id"]
          # Update jobs infos
          submitted_jobs=Jobset.new
          submitted_jobs.fill(jobs,true)
          submitted_jobs.update!(
                                 { 'state' => 'submitted', 
                                   'submission_time' => Time::now(),
                                   'cluster_id' => cluster_id,
                                 },'jobs' )
          submitted_jobs.match_remote_ids(cluster_id,j["id"])
        end
      end
      JOBLIBLOGGER.debug("Remote ids of array jobs just submitted on #{cluster.description["name"]}: #{array_jobs.join(',')}")
      return array_jobs
    end

    # This function updates the "remote_id" field of the jobs. It matches
    # each job of a oar array_job with the corresponding cigri job.
    # For this, we ensure that the parameters part of the oar command is the same
    # of the param value in the cigri database.
    def match_remote_ids(cluster_id,array_id)
      cluster=Cluster.new(:id => cluster_id)
      begin
        cluster_jobs=cluster.get_jobs(:array => array_id)
      rescue
        # TODO: We should create an event here
        # Could not get the submitted jobs id
        JOBLIBLOGGER.error("Could not get the ids of the array job #{array_id}, losing jobs!") 
      end
      # For each job of the array on the cluster
      cluster_jobs.each do |cluster_job|
        matched=0
        # we try to match the parameters of each job of the jobset
        jobs.each do |cigri_job|
          if cluster_job["command"].split(nil,2)[1] == cigri_job.props[:param]
            cigri_job.update({'remote_id' => cluster_job["id"]},"jobs")
            matched=1
            break
          end  
        end
        if matched == 0
          JOBLIBLOGGER.error("Could not find the CIGRI job corresponding to the OAR job #{cluster_job["id"]} !")
        end
      end
    end

  end # Class Jobset


  # Job to launch class
  # A Job to launch instance can be get from the database or newly created
  # See Datarecord class for more doc
  class Jobtolaunch < Datarecord
    attr_reader :props

    # Creates a new job to launch entry or get it from the database
    def initialize(props={})
      super("jobs_to_launch",props)
    end

  end # class Jobtolaunch

  # JobtolaunchSet class
  # Example: 
  #  jobs=Cigri::JobtolaunchSet.new({:where => "cluster_id=1"})
  class JobtolaunchSet < Dataset

    # Creates the new jobset
    def initialize(props={})
      props[:where] += " AND task_id = bag_of_tasks.id" if props[:where]
      super("jobs_to_launch, bag_of_tasks", props)
    end

    # Alias to the dataset records
    def jobs
      @records
    end

    # Get max n jobs to launch on cluster cluster_id
    def get_next(cluster_id,n)
      fill(get("jobs_to_launch,bag_of_tasks","*","cluster_id=#{cluster_id} 
                                                    AND task_id=bag_of_tasks.id
                                                    ORDER BY jobs_to_launch.id
                                                    LIMIT #{n}
                                                 "))
      return self.length
    end

    # Take the jobs from the bag of tasks and return newly created jobs.
    # This is done in an atomical way to prevent from losing jobs in case of a 
    # crash. This is why we directly call an iolib function ithout using datarecords.
    def take
      jobids=take_tasks(@dbh,self.ids)
      Jobset.new(:where => "jobs.id in (#{jobids.join(',')})")
    end

  end # Class JobtolaunchSet



  # Campaign class
  # A Campaign instance can be get from the database or newly created
  # See Datarecord class for more doc
  class Campaign < Datarecord
    attr_reader :props, :clusters

    # Creates a new campaign entry or get it from the database
    def initialize(props={})
      super("campaigns",props)
      @clusters = {}
      @props[:finished_jobs] = nb_completed_tasks if @props and !props[:bypass_finished_jobs]
    end

    # Fills the @cluster hash with the properties (JDL) of this campaign
    # This hash looks like:
    #  {1=>
    #    [{"resources"=>"core=1"},
    #     {"exec_file"=>"$HOME/cigri-3/tmp/test1.sh"}],
    #   3=>
    #    [{"resources"=>"core=1"},
    #     {"exec_file"=>"$HOME/cigri-3/tmp/test1.sh"}]}
    #
    def get_clusters
      db_connect() do |dbh|
        get_campaign_properties(dbh, id).each do |row|
          cluster_id = row["cluster_id"].to_i
          @clusters[cluster_id] = {} if @clusters[cluster_id].nil?
          @clusters[cluster_id][row["name"]] = row["value"]
        end
      end
    end

    # Checks if a campaign has remaining tasks to execute
    def have_remaining_tasks?
      db_connect() do |dbh|
        return get_campaign_remaining_tasks_number(dbh, id) > 0
      end
    end

    def min_task_id
      db_connect() do |dbh|
        return get_min_param_id(dbh, id)
      end
    end

    def tasks(limit, offset)
      db_connect() do |dbh|
        return get_campaign_tasks(dbh, id, limit, offset)
      end
    end

    # Return the number of completed tasks
    def nb_completed_tasks
      db_connect() do |dbh|
        return get_campaign_nb_finished_jobs(dbh, id)
      end
    end

    # Return true if campaign has at least an active cluster
    def have_active_clusters?
      @clusters.each do |cluster|
        #TODO: should check for blacklisted clusters (colombo)
        return true
      end
      false
    end

  end # class Campaign

  # Campaignset class
  # Example: 
  #  campaigns=Cigri::Campaigns.new
  #  campaigns.get_running
  class Campaignset < Dataset

    # Creates the new campaignset
    def initialize(props = {})
      super("campaigns", props)
      to_campaigns
    end

    # Alias to the dataset records
    def campaigns
      @records
    end

    # Convert the datarecords objects to campaign objects
    # couldn't find someting similar to "extend Module"...
    def to_campaigns
      finished_jobs = get_campaigns_nb_finished_jobs(@dbh, ids)
      campaigns=[]
      @records.each do |record|
        props = record.props
        props[:nodb] = true
        props[:bypass_finished_jobs] = true
        campaign = Campaign.new(props)
        campaign.props[:finished_jobs] = finished_jobs[campaign.id]
        campaigns << campaign
      end
      @records = campaigns
    end

    # Fill the campaignset with the currently running campaigns
    def get_running
      fill(get("campaigns","*","state = 'in_treatment'"))
      to_campaigns
    end
    
    # Fill the campaign set with unfinished campaigns (paused or running)
    def get_unfinished
      fill(get("campaigns","*","state IN ('in_treatment', 'paused')"))
      to_campaigns
    end
 
  end # Class Campaignset
  
end # module Cigri
