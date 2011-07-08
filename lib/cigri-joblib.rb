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

CONF ||= Cigri.conf
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
  class Jobset < Dataset

    # Creates the new jobset
    def initialize(props={})
      super("jobs",props)
    end

    # Alias to the dataset records
    def jobs
      @records
    end

    # Fill the jobset with the currently running jobs
    def get_running
      fill(get("jobs","*","state = 'running'"))
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
      array_jobs=[]
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
        j=cluster.submit_job(submission)
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
                                 } )
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
      cluster_jobs=cluster.get_jobs(:array => array_id)
      # For each job of the array on the cluster
      cluster_jobs.each do |cluster_job|
        matched=0
        # we try to match the parameters of each job of the jobset
        jobs.each do |cigri_job|
          if cluster_job["command"].split(nil,2)[1] == cigri_job.props[:param]
            cigri_job.update({'remote_id' => cluster_job["id"]})
            matched=1
            break
          end  
        end
        if matched == 0
          JOBLIBLOGGER.error("Could not find the CIGRI job corresponding to the OAR job #{cluster_job["id"]} !")
        end
      end
    end

    # Get jobs that have just been submitted on cluster_id
    def get_submitted(cluster_id)
      fill(get("jobs","*","
                    (state = 'submitted' or state = 'remote_waiting') 
                      and cluster_id=#{cluster_id}"))
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
      if props[:where]
        props[:where] += " AND task_id=bag_of_tasks.id"
      end
      super("jobs_to_launch,bag_of_tasks",props)
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

    # Remove the jobs from the queue and the bag of task
    def remove
      # Remove from the bag of tasks
      bag=Dataset.new('bag_of_tasks',{:where => "id in (#{self.ids.join(',')})"})
      bag.delete
      # Remove from the queue
      self.delete('jobs_to_launch','task_id')
    end

    # Register the jobs into the jobs table (creates new jobs)
    # returns a jobset of the newly created jobs
    def register
      values=[]
      @records.each do |record|
        values << {
                    :campaign_id => record.props[:campaign_id],
                    :state => "to_launch",
                    :cluster_id => record.props[:cluster_id],
                    :param => record.props[:param],
                    :name => record.props[:param].split[0]
                  }
      end
      Jobset.new(:values => values)
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
      @clusters={}
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
      dbh=db_connect() do |dbh|
        get_campaign_properties(dbh,id).each do |row|
          cluster_id=row["cluster_id"]
          @clusters[cluster_id]={} if @clusters[cluster_id].nil?
          @clusters[cluster_id][row["name"]]=row["value"]
        end
      end
    end

    # Return false if the campaign has no more tasks to run
    # Else, returns the number of tasks remaining
    def have_remaining_tasks?
      dbh=db_connect() do |dbh|
        count=get_campaign_remaining_tasks_number(dbh,id)
        return count if count != 0
      end
    end

    # Return false if campaign has no active clusters
    def have_active_clusters?
      have=0
      @clusters.each do |cluster|
        #TODO: should check for blacklisted clusters (colombo)
        have += 1
      end
      return have if have != 0
    end

  end # class Campaign

  # Campaignset class
  # Example: 
  #  campaigns=Cigri::Campaigns.new
  #  campaigns.get_running
  class Campaignset < Dataset

    # Creates the new campaignset
    def initialize(props={})
      super("campaigns",props)
      to_campaigns
    end

    # Alias to the dataset records
    def campaigns
      @records
    end

    # Convert the datarecords objects to campaign objects
    # couldn't find someting similar to "extend Module"...
    def to_campaigns
      campaigns=[]
      @records.each do |record|
        props=record.props
        props[:nodb]=true
        campaigns << Campaign.new(props)
      end
      @records = campaigns
    end

    # Fill the campaignset with the currently running campaigns
    def get_running
      fill(get("campaigns","*","state = 'in_treatment'"))
      to_campaigns
    end
 
  end # Class Campaignset





end # module Cigri
