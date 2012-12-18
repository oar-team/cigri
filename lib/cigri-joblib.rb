#!/usr/bin/ruby -w
#
# This library contains the classes relative to Jobs
# It may be considered as an extension to the iolib, as
# it still makes SQL queries, but more in a "meta" way
#

require 'cigri'
require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-iolib'
require 'cigri-clusterlib'
require 'json'

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
      begin
        @props[:runner_options]=JSON.parse(@props[:runner_options])
      rescue
        JOBLIBLOGGER.warn("Couldn't convert runner_options field of job #{id}")   
      end
    end

    # Clone the job into the bag of tasks for resubmission of the same job
    # A re-submitted job has a priority of 20 (higher than default which is 10)
    def resubmit
      Datarecord.new("bag_of_tasks",{:param_id => @props[:param_id], :campaign_id => @props[:campaign_id], :priority => '20'})
    end

    # Same as resubmit, but with a 0 priority, so that the job is at the end of the queue
    def resubmit_end
      Datarecord.new("bag_of_tasks",{:param_id => @props[:param_id], :campaign_id => @props[:campaign_id], :priority => '0'})
    end
  
    # Kill a job running on a cluster
    def kill
      if props[:cluster_id]
        cluster=Cluster.new(:id => props[:cluster_id])
        if !cluster.blacklisted?
          if props[:state] == "running" or props[:state] == "remote_waiting"
            if props[:remote_id]
              cluster.delete_job(props[:remote_id],props[:grid_user])
            else
              JOBLIBLOGGER.warn("Can't kill a job without a remote_id: #{id}!")
            end
          else
            JOBLIBLOGGER.warn("Can't kill a job that is not running or remote_waiting: #{id}!")
          end
        else
          JOBLIBLOGGER.debug("Not killing job on a blacklisted cluster: #{id}")
        end
      else
        JOBLIBLOGGER.warn("Can't kill a job without a cluster_id: #{id}!")
      end  
    end

    # Get the state for a job that is part of a batch (jobs grouping)
    # Output:
    #  Mimic a OAR job so that we can use the Colombo::analyze_remote_job_events function
    #  {state=<notstarted|running|finished>,start_time,stop_time,exit_code,stderr_file,launching_directory}
    def get_subjob_state(cluster=nil)
      output={}
      cluster=Cluster.new(:id => cluster_id) if cluster.nil?
      status_file=""
      begin 
        status_file=cluster.get_file("/~/cigri_batch_state_"+id.to_s,@props[:grid_user])
        start_time=nil
        exit_code=nil
        stop_time=nil
        status_file.each_line do |line|
          tag=line.split(/=/)
          case tag[0]
          when /BEGIN_DATE/
            start_time=tag[1]
            output["state"]="running"
          when /RET/
            exit_code=tag[1]
          when /END_DATE/
            stop_time=tag[1]
            output["state"]="finished"
          end
        end
      rescue Cigri::ClusterAPINotFound => e
        output["state"]="notstarted"
      rescue
        raise
      end
      output["events"]=[]
      return output
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
               jobs.campaign_id as campaign_id, param_id, batch_id, cluster_id, 
               collect_id, jobs.state as state, return_code, 
               jobs.submission_time as submission_time, start_time, 
               stop_time, node_name, resources_used, remote_id, tag, runner_options"
      @join="jobs.param_id=parameters.id and jobs.campaign_id=campaigns.id"
      if (not props[:where].nil?)
        props[:where]+=" and #{@join}"
        if (props[:what].nil?)
          props[:what]=@fields
        end
      end
      super("jobs,parameters,campaigns",props)
      to_jobs
    end

    # This method converts the Datarecord objects into Job objects
    def to_jobs
      jobs=[]
      @records.each do |record|
        props = record.props
        props[:nodb] = true
        job = Job.new(props)
        jobs << job
      end
      @records = jobs
    end

    # Alias to the dataset records
    def jobs
      @records
    end

    # Fill the jobset with the launching jobs
    def get_launching(cluster_id=nil)
      cluster_query=""
      if not cluster_id.nil?
        cluster_query="and cluster_id=#{cluster_id}"
      end
      fill(get("jobs,parameters,campaigns",@fields,"jobs.state = 'launching' and #{@join} #{cluster_query}"))
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

    # Add properties from the JDL to a submission string
    def add_jdl_properties(submission_string,campaign,cluster_id)
       submission_string["walltime"]=campaign.clusters[cluster_id]["walltime"] if campaign.clusters[cluster_id]["walltime"]
       submission_string["directory"]=campaign.clusters[cluster_id]["exec_directory"] if campaign.clusters[cluster_id]["exec_directory"]
       submission_string["properties"]=campaign.clusters[cluster_id]["properties"] if campaign.clusters[cluster_id]["properties"]
       submission_string
    end

    # Submit a single job on the given cluster
    def submit_single_job(cluster,job,campaign,submission_string)
       # Add properties from the JDL
      submission_string=add_jdl_properties(submission_string,campaign,cluster.id)
      JOBLIBLOGGER.debug("Submitting new job on #{cluster.description["name"]}.")
      # Actual submission
      j=cluster.submit_job(submission_string,campaign.props[:grid_user])
      if j.nil?
        JOBLIBLOGGER.error("Unhandled error when submitting job on #{cluster.description["name"]}!")
      else
         # Update job info
         job.update(
                     { 'state' => 'submitted', 
                       'submission_time' => Time::now(),
                       'cluster_id' => cluster.id,
                       'remote_id' => j["id"]
                     },'jobs' )
        JOBLIBLOGGER.debug("Remote id of single job just submitted on #{cluster.description['name']}: #{j['id']}")
        return j['id']
      end
    end 

    # Submit an array job on the given cluster
    def submit_array_job(cluster,jobs,campaign,submission_string)
       # Add properties from the JDL
      submission_string=add_jdl_properties(submission_string,campaign,cluster.id)
      JOBLIBLOGGER.debug("Submitting new array job on #{cluster.description["name"]}.")
      # Actual submission
      launching_jobs=Jobset.new
      launching_jobs.fill(jobs,true)       
      launching_jobs.update({'state' => 'launching'})
      j=cluster.submit_job(submission_string,campaign.props[:grid_user])
      if j.nil?
        JOBLIBLOGGER.error("Unhandled error when submitting jobs on #{cluster.description["name"]}!")
      else
        # Update jobs infos
        launching_jobs.update!(
                               { 'state' => 'submitted', 
                                 'submission_time' => Time::now(),
                                 'cluster_id' => cluster.id,
                               },'jobs' )
        launching_jobs.match_remote_ids(cluster.id, campaign.clusters[cluster.id]["exec_file"], j["id"])
        JOBLIBLOGGER.debug("Remote id of array job just submitted on #{cluster.description['name']}: #{j['id']}")
        return j['id']
      end
    end 

    # Submit jobs on the given cluster grouping them into a unique batch job
    def submit_batch_job(cluster,jobs,campaign,runner_options)
      if runner_options["temporal_grouping"]
        script="#!/bin/bash\nset +e\n"
        jobs.each do |job|
          state_file="cigri_batch_state_"+job.id.to_s
          stdout_file="cigri_batch_stdout_"+job.id.to_s
          stderr_file="cigri_batch_stderr_"+job.id.to_s
          script+="echo \"BEGIN_DATE=`date +%s`\" >> #{state_file}\n"
          #TODO: cd into the workdir?
          script+=campaign.clusters[cluster.id]["exec_file"]+" "+job.props[:param]
          script+=" > #{stdout_file} 2>#{stderr_file}\n"
          script+="echo \"RET=\\$?\" >> #{state_file}\n"
          script+="echo \"END_DATE=`date +%s`\" >> #{state_file}\n"
        end
        submission_string={ "resources" => campaign.clusters[cluster.id]["resources"],
                            "command" => script
                          }
        if runner_options["besteffort"]
           submission_string["type"]="besteffort"
        end
      elsif runner_options["dimensional_grouping"]
         #TODO
      end
       # Add properties from the JDL
      submission_string=add_jdl_properties(submission_string,campaign,cluster.id)
      JOBLIBLOGGER.debug("Submitting new batch job on #{cluster.description["name"]}.")
      # Actual submission
      launching_jobs=Jobset.new
      launching_jobs.fill(jobs,true)       
      launching_jobs.update({'state' => 'launching','tag' => 'batch'})
      j=cluster.submit_job(submission_string,campaign.props[:grid_user])
      if j.nil?
        JOBLIBLOGGER.error("Unhandled error when submitting jobs on #{cluster.description["name"]}!")
      else
        # Update jobs infos
        launching_jobs.update!(
                               { 'state' => 'submitted', 
                                 'submission_time' => Time::now(),
                                 'cluster_id' => cluster.id,
                                 'remote_id' => j['id']
                               },'jobs' )
        JOBLIBLOGGER.debug("Remote id of batch job just submitted on #{cluster.description['name']}: #{j['id']}")
        return j['id']
      end
    end 

    # Submit the jobset on the cluster corresponding to cluster_id
    # Second implementation
    # Grouping optimization is done whenever it is possible: 
    #   - for temporal grouping, creates batches of jobs executed sequentially
    #   - for dimensional grouping, creates batches of jobs executed in parallel
    #   - when no grouping is requested, submit as array jobs whenever it is possible
    def submit2(cluster_id)
      submitted_jobs=[]

      # Get the cluster
      cluster=Cluster.new(:id => cluster_id)

      # Treat each campaign separately
      self.campaigns.each do |campaign_id|
        campaign=Campaign.new(:id => campaign_id)
        # Don't treat campaigns for which the cluster is blacklisted
        if cluster.blacklisted?(:campaign_id => campaign.id)
          JOBLIBLOGGER.info("Not submitting jobs on #{cluster.name} for campaign #{campaign.id} because of blacklist.")
        # Cluster ok for this campaign
        else
          campaign.get_clusters
          # Select the jobs belonging to the current campaign
          myjobs=@records.select {|job| job.props[:campaign_id] == campaign_id}
          # Treat prologue and epilogue jobs
          ["prologue","epilogue"].each do |tag|
            tagged_job=myjobs.select {|job| job.props[:tag] == tag}
            if tagged_job.length > 0
              submitted_jobs << submit_single_job(cluster,tagged_job[0],campaign,{
                               "resources" => "resource_id=1",
                               "command" => campaign.clusters[cluster_id][tag] } )
              myjobs.delete(tagged_job[0])
            end
          end
          # Group the jobs by runner_options
          by_options_jobs={}
          myjobs.each do |job|
            runner_options=job.props[:runner_options]
            if by_options_jobs[runner_options].nil?
              by_options_jobs[runner_options]=[]
            end
            by_options_jobs[runner_options] << job
          end
          # For each runner_options, we can try to group
          by_options_jobs.each do |runner_options,jobs|
            # Batch (temporal, dimensional) grouping
            if runner_options["dimensional_grouping"]
              #TODO
              JOBLIBLOGGER.warn("Dimensional grouping not yet supported!")
            end
            if runner_options["temporal_grouping"] 
              submitted_jobs << submit_batch_job(cluster,jobs,campaign,runner_options)
            else
              # Array grouping
              params=jobs.collect {|job| job.props[:param]}
              submission = {
                            "param_file" => params.join("\n"),
                            "resources" => campaign.clusters[cluster_id]["resources"],
                            "command" => campaign.clusters[cluster_id]["exec_file"]
                           }
              if runner_options["besteffort"]
                submission["type"]="besteffort"
              end
              submitted_jobs << submit_array_job(cluster,jobs,campaign,submission)
            end
          end # Each runner option
        end # Blacklisted cluster
      end # Each campaign
      return submitted_jobs
    end

    # Submit a set of jobs, using OAR array jobs if possible
    # So, group the jobs by campaigns as only jobs from a
    # same campaign can be launched in the same array
    def submit(cluster_id)
      array_jobs = []
      cluster=Cluster.new(:id => cluster_id)
      self.campaigns.each do |campaign_id|
        campaign=Campaign.new(:id => campaign_id)
        if cluster.blacklisted?(:campaign_id => campaign.id)
          JOBLIBLOGGER.info("Not submitting jobs on #{cluster.name} for campaign #{campaign.id} because of blacklist.")
        else
          campaign.get_clusters
          jobs=@records.select {|job| job.props[:campaign_id] == campaign_id}
          # Now, we got the jobs of a campaign
          # We need to split again, by runner_options
          runner_options=jobs.map{|job| job.props[:runner_options]}
          runner_options.uniq!
          runner_options.each do |runner_option|
            params=jobs.collect {|job| job.props[:param]}
            array=true
            # Prologue job
            if jobs[0].props[:tag] == "prologue"
              submission = {
                            "resources" => "resource_id=1",
                            "command" => campaign.clusters[cluster_id]["prologue"]
                           }
              array=false 
            # Epilogue job
            elsif jobs[0].props[:tag] == "epilogue"
              submission = {
                            "resources" => "resource_id=1",
                            "command" => campaign.clusters[cluster_id]["epilogue"]
                           }
              array=false
            # Other jobs
            else
              submission = {
                            "param_file" => params.join("\n"),
                            "resources" => campaign.clusters[cluster_id]["resources"],
                            "command" => campaign.clusters[cluster_id]["exec_file"]
                           }
            end
            # Properties from the JDL
            submission["walltime"]=campaign.clusters[cluster_id]["walltime"] unless campaign.clusters[cluster_id]["walltime"]
            submission["directory"]=campaign.clusters[cluster_id]["exec_directory"] unless campaign.clusters[cluster_id]["exec_directory"]
            submission["properties"]=campaign.clusters[cluster_id]["properties"] unless campaign.clusters[cluster_id]["properties"]
            # MAYBE TODO: specific walltime,directory,... from JDL for pro/epilogue scripts

            # Runner options
            if runner_option["besteffort"]
              submission["type"]="besteffort"
            end
          
            # TODO: manage grouping
 
            # Submitting the array job
            if array 
              JOBLIBLOGGER.info("Submitting new array job on #{cluster.description["name"]} with #{params.length} parameter(s).")
              launching_jobs=Jobset.new
              launching_jobs.fill(jobs,true)       
              launching_jobs.update({'state' => 'launching'})
              j=cluster.submit_job(submission,campaign.props[:grid_user])
              if j.nil?
                JOBLIBLOGGER.error("Unhandled error when submitting jobs on #{cluster.description["name"]}!")
              else
                array_jobs << j["id"]
                # Update jobs infos
                launching_jobs.update!(
                                   { 'state' => 'submitted', 
                                     'submission_time' => Time::now(),
                                     'cluster_id' => cluster_id,
                                   },'jobs' )
                launching_jobs.match_remote_ids(cluster_id, campaign.clusters[cluster_id]["exec_file"], j["id"])
              end
            # Submitting a unique job (prologue or epilogue)
            else
              JOBLIBLOGGER.info("Submitting new job on #{cluster.description["name"]}.")
              j=cluster.submit_job(submission,campaign.props[:grid_user])
              if j.nil?
                JOBLIBLOGGER.error("Unhandled error when submitting job on #{cluster.description["name"]}!")
              else
                array_jobs << j["id"]
                # Update job info
                jobs[0].update(
                                 { 'state' => 'submitted', 
                                   'submission_time' => Time::now(),
                                   'cluster_id' => cluster_id,
                                   'remote_id' => j["id"]
                                 },'jobs' )
              end
            end
          end
        end
      end
      JOBLIBLOGGER.debug("Remote ids of (array) jobs just submitted on #{cluster.description["name"]}: #{array_jobs.join(',')}") if array_jobs.length > 0
      return array_jobs
    end

    # This function updates the "remote_id" field of the jobs. It matches
    # each job of a oar array_job with the corresponding cigri job.
    # For this, we ensure that the parameters part of the oar command is the same
    # of the param value in the cigri database.
    def match_remote_ids(cluster_id, command, array_id)
      cluster  = Cluster.new(:id => cluster_id)
      begin
        cluster_jobs = cluster.get_jobs(:array => array_id)
      rescue
        # TODO: We should create an event here
        # Could not get the submitted jobs id
        JOBLIBLOGGER.error("Could not get the ids of the array job #{array_id}, losing jobs!") 
      end
      # For each job of the array on the cluster
      cluster_jobs.each do |cluster_job|
        matched = false
        # we try to match the parameters of each job of the jobset
        index = jobs.index {|cigri_job| 
                    cluster_job["command"].split(/ /,2)[1].to_s.include?("#{cigri_job.props[:param]}")}
        if index
          cigri_job = jobs.delete_at(index)
          cigri_job.update({'remote_id' => cluster_job["id"]}, "jobs")
        else
          JOBLIBLOGGER.error("Could not find the CIGRI job corresponding to the OAR job #{cluster_job["id"]} !")
        end
      end
    end
    
    def ids
      ids=[]
      jobs.each do |job|
        ids << job.id
      end
      ids
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
      props[:where] += " AND bag_of_tasks.id = jobs_to_launch.task_id" if props[:where]
      super("jobs_to_launch, bag_of_tasks", props)
    end

    # Alias to the dataset records
    def jobs
      @records
    end

    # Get jobs to launch on cluster cluster_id, with a limit per campaign
    # The tap hash contains the maximum jobs to get per campaign_id 
    def get_next(cluster_id,tap={})
      jobs=get("jobs_to_launch,bag_of_tasks","*","cluster_id=#{cluster_id} 
                                                    AND task_id=bag_of_tasks.id
                                                    ORDER BY bag_of_tasks.priority DESC, jobs_to_launch.id")
      counts={}
      jobs.each do |job|
        campaign_id=job[:campaign_id].to_i
        counts[campaign_id] ? counts[campaign_id]+=1 : counts[campaign_id]=1
        tap[campaign_id] ||= 0
        if tap[campaign_id] >=  counts[campaign_id]
          job[:nodb]=true
          @records << Datarecord.new(@table,job) 
        end
      end
      return self.length
    end

    # Take the jobs from the bag of tasks and return newly created jobs.
    # This is done in an atomical way to prevent from losing jobs in case of a 
    # crash. This is why we directly call an iolib function ithout using datarecords.
    def take
      check_connection!
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
    # Warning: these are not Cluster objects!
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
    def has_remaining_tasks?
      db_connect() do |dbh|
        return get_campaign_remaining_tasks_number(dbh, id) > 0
      end
    end

    # Check if a campaign has active jobs
    def has_active_jobs?
      db_connect() do |dbh|
        return get_campaign_active_jobs_number(dbh, id) > 0
      end
    end

    # Check if a campaign has jobs to launch in clusters queues
    def has_to_launch_jobs?
      db_connect() do |dbh|
        return get_campaign_to_launch_jobs_number(dbh, id) > 0
      end
    end

    # Check if a campaign has launching jobs
    def has_launching_jobs?
      db_connect() do |dbh|
        return get_campaign_launching_jobs_number(dbh, id) > 0
      end
    end

    # Check if a campaign has open events
    def has_open_events?
      db_connect() do |dbh|
        return get_campaign_nb_events(dbh, id) > 0
      end
    end

    # Check if a campaign is finished
    def finished?
      return false if has_remaining_tasks?
      return false if has_to_launch_jobs?
      return false if has_launching_jobs?
      return false if has_active_jobs?
      @clusters.each do |id,cluster|
        return false if not epilogue_ok?(id)
      end
      return true
    end

    def tasks(limit, offset)
      db_connect() do |dbh|
        return get_campaign_tasks(dbh, id, limit, offset)
      end
    end

    def task(task_id)
      db_connect() do |dbh|
        return get_campaign_task(dbh, id, task_id)
      end
    end

    # Get open events
    def events(limit, offset)
      db_connect() do |dbh|
        return get_campaign_events(dbh, id, limit, offset)
      end
    end

    # Return the number of completed tasks
    def nb_completed_tasks
      db_connect() do |dbh|
        return get_campaign_nb_finished_jobs(dbh, id)
      end
    end

    # Return the number of open events
    def nb_events
      db_connect() do |dbh|
        return get_campaign_nb_events(dbh, id)
      end
    end

    # Return true if campaign has at least an active cluster
    def have_active_clusters?
      @clusters.each_key do |cluster_id|
        cluster=Cigri::Cluster.new(:id=>cluster_id)
        return true unless cluster.blacklisted?(:campaign_id=>id)
      end
      false
    end

    # Return true if the prologue has been executed on the specified cluster
    # or if there's no prologue to execute
    def prologue_ok?(cluster_id)
      return true unless @clusters[cluster_id]["prologue"]
      Cigri::Jobset.new({:where => "tag='prologue' 
                                  and jobs.state='terminated' 
                                  and jobs.campaign_id=#{id}
                                  and jobs.cluster_id=#{cluster_id}"}).length > 0
    end

    # Return true if the epilogue has been executed on the specified cluster
    # or if there's no epilogue to execute
    def epilogue_ok?(cluster_id)
      return true unless @clusters[cluster_id]["epilogue"]
      Cigri::Jobset.new({:where => "tag='epilogue' 
                                  and jobs.state='terminated' 
                                  and jobs.campaign_id=#{id}
                                  and jobs.cluster_id=#{cluster_id}"}).length > 0
    end

    # Return true if the prologue is running on the specified cluster
    def prologue_running?(cluster_id)
      Cigri::Jobset.new({:where => "tag='prologue' 
                                  and (jobs.state='running' or jobs.state='remote_waiting'
                                       or jobs.state='to_launch' or jobs.state='launching'
                                       or jobs.state='submitted')
                                  and jobs.campaign_id=#{id}
                                  and cluster_id=#{cluster_id}"}).length > 0
    end

    # Return true if the epilogue is running on the specified cluster
    def epilogue_running?(cluster_id)
      Cigri::Jobset.new({:where => "tag='epilogue' 
                                  and (jobs.state='running' or jobs.state='remote_waiting'
                                       or jobs.state='to_launch' or jobs.state='launching'
                                       or jobs.state='submitted')
                                  and jobs.campaign_id=#{id}
                                  and cluster_id=#{cluster_id}"}).length > 0
    end

    # Get the average job duration (in seconds)
    # returns 2 values: [average,stddev]
    def average_job_duration
      res=nil
      db_connect do |dbh|
        res=get_average_job_duration(dbh,id)
      end
      return res
    end

    # Get the job throughput (in jobs/seconds) in the last time_window
    def throughput(time_window)
      #TODO
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
      check_connection!
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

    # Returns a hash campaign_id => grid_user
    def get_users
      Hash[@records.map {|record| [record.id,record.props[:grid_user]]}]
    end

    # Return all the clusters (objects) that are not blacklisted and used by at least
    # one campaign of this Campaignset
    # This is mainly to create a cache of cluster objects, for optimization
    def get_clusters
      clusters={}
      @records.each do |campaign|
        campaign.get_clusters
        campaign.clusters.each_key do |cluster_id|
          if not clusters[cluster_id]
            cluster=Cigri::Cluster.new(:id => cluster_id)
            if cluster.blacklisted?
              clusters[cluster_id]=nil
            else
              clusters[cluster_id]=cluster
            end
          end
        end
      end
      return clusters.values.compact
    end
  
    # Get a cluster from a cluster array (a clusters cache) by its id
    def get_cluster(cache,id)
      cache[cache.index {|c| c.id == id}]
    end

    # Compute an ordered list of (campaign_id,cluster_id) on which we can schedule jobs
    # The order defines the priority for scheduling.
    # The presence of a couple is conditionned by blacklists, prologue and stress_factor.
    # The order depends on users_priority.
    def compute_orders
      couples=[]
      clusters_cache=get_clusters
      # First pass: get the active couples (remove blacklisted and under stress clusters)
      @records.each do |campaign|
        campaign.get_clusters
        campaign.clusters.each_key do |cluster_id|
          cluster=get_cluster(clusters_cache,cluster_id)
          if campaign.prologue_ok?(cluster_id) and 
               not cluster.blacklisted? and 
               not cluster.under_stress?
             couples << [campaign.id,cluster_id]
          end
        end
      end
      # Second pass: order the couples by users affinity and fifo
      users=get_users
      ordered_couples=[]
      clusters_cache.sort{|a,b| a.props[:power] <=> b.props[:power]}
      clusters_cache.each do |cluster|
        # TODO: Any way to do the following two lines in one shot?
        campaigns=couples.select{|c| c[1]==cluster.id}
        campaigns.map!{|c| c[0].to_i }
        # Get users priority
        users_priority=Dataset.new('users_priority',:where => "cluster_id = #{cluster.id}")
        priorities={}
        campaigns.each do |campaign_id|
          u=users_priority.records.select{|u| u.props[:grid_user] == users[campaign_id]}[0]
          if u
            priorities[campaign_id]=u.props[:priority].to_i
          else
            priorities[campaign_id]=0
          end
        end
        # Do a stable sort on priorities (stable for ids)
        campaigns=campaigns.sort_by{|x| [priorities[x]*-1,x]}
        campaigns.each do |c|
          ordered_couples << [cluster.id,c]
        end
      end
      return ordered_couples
    end
 
  end # Class Campaignset
  
end # module Cigri
