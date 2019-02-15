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
require 'cigri-runnerlib'
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

    def campaign_running?
      campaign=Campaign.new(:id => @props[:campaign_id],:bypass_finished_jobs => true)
      campaign.props[:state] == 'in_treatment' or campaign.props[:state] == 'paused'
    end

    # Do some checks to know if the job can be re-submitted
    def check_resubmit
      if not campaign_running?
        JOBLIBLOGGER.info("Not resubmiting job #{id} of non-running campaign")
        return false
      end
      if @props[:tag] == "prologue" or @props[:tag] == "epilogue" 
        JOBLIBLOGGER.info("Not resubmiting job #{id} as it is tagged as #{@props[:tag]}")
        return false
      end
      true
    end

    # Clone the job into the bag of tasks for resubmission of the same job
    # A re-submitted job has a priority of 20 (higher than default which is 10)
    def resubmit
      if check_resubmit
        JOBLIBLOGGER.debug("Resubmiting parameter #{@props[:param_id]}")   
        Datarecord.new("bag_of_tasks",{:param_id => @props[:param_id], :campaign_id => @props[:campaign_id], :priority => '20'})
      end
    end

    # Same as resubmit, but with a 0 priority, so that the job is at the end of the queue
    def resubmit_end
      if check_resubmit
        JOBLIBLOGGER.debug("Resubmiting parameter #{@props[:param_id]} at end of queue")   
        Datarecord.new("bag_of_tasks",{:param_id => @props[:param_id], :campaign_id => @props[:campaign_id], :priority => '0'})
      end
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
      rescue Cigri::ClusterAPINotFound
        output["state"]="notstarted"
      rescue
        raise
      end
      output["events"]=[]
      return output
    end

    # Decrease the affinity of this job's parameter on its cluster
    def decrease_affinity
      db_connect() do |dbh|
        decrease_task_affinity(dbh,@props[:param_id],@props[:cluster_id])
      end
    end
     
    # Get current affinity
    def get_affinity
      db_connect() do |dbh|
        affinity=get_task_affinity(dbh,@props[:param_id],@props[:cluster_id])
        if affinity.nil?
          return 0
        else
          return affinity[3]
        end
      end
    end

    # Reset affinity to 0
    def reset_affinity
      db_connect() do |dbh|
        reset_task_affinity(dbh,@props[:param_id],@props[:cluster_id])
      end
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
               jobs.campaign_id as campaign_id, param_id, batch_id, jobs.cluster_id, 
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

   # Get running jobs with expired walltime (walltime + 30 minutes)
   # Those jobs should not be running as they should already be killed by OAR
   def get_expired
     fill(get("jobs,parameters,campaigns,campaign_properties",@fields,"
               jobs.state='running' 
               AND jobs.campaign_id=campaign_properties.campaign_id
               AND jobs.cluster_id=campaign_properties.cluster_id
               AND campaign_properties.name='walltime'
               AND campaign_properties.value::INTERVAL + '0:30:00' < (now()-jobs.start_time)::TIME
               AND #{@join}"))
   end
    

   # Get the ids (array) of all campaigns from this jobset
    def campaigns
      campaigns={}
      @records.each do |job|
        campaigns[job.props[:campaign_id].to_i]=1
      end
      return campaigns.keys
    end

    # Remove jobs from blacklisted campaigns
    def remove_blacklisted(cluster_id)
      new_records=[]
      blacklist={}
      cluster=Cluster.new(:id => cluster_id)
      campaigns.each do |campaign_id|
        blacklist[campaign_id]=true if cluster.blacklisted?(:campaign_id=>campaign_id) 
      end
      @records.each do |record|
        new_records << record if not blacklist[record.props[:campaign_id].to_i]
      end
      @records=new_records
    end

    # Add properties from the JDL to a submission string
    def add_jdl_properties(submission_string,campaign,cluster_id,tag=nil)
       walltime=nil
       if tag and tag=="prologue"
         walltime=campaign.clusters[cluster_id]["prologue_walltime"] if campaign.clusters[cluster_id]["prologue_walltime"]
       elsif tag and tag=="epilogue"
         walltime=campaign.clusters[cluster_id]["epilogue_walltime"] if campaign.clusters[cluster_id]["epilogue_walltime"]
       end
       if walltime.nil? && campaign.clusters[cluster_id]["walltime"]
         walltime=campaign.clusters[cluster_id]["walltime"]
       end
       submission_string["resources"]=submission_string["resources"]+",walltime="+walltime if walltime and submission_string["resources"].kind_of?(String)
       #expand {CAMPAIGN_ID} macro into exec_directory
       exec_directory=campaign.clusters[cluster_id]["exec_directory"].gsub(/{CAMPAIGN_ID}/,campaign.id.to_s)
       submission_string["directory"]=exec_directory if campaign.clusters[cluster_id]["exec_directory"] and tag != "prologue" and tag != "epilogue"
       submission_string["property"]=campaign.clusters[cluster_id]["properties"] if campaign.clusters[cluster_id]["properties"]
       submission_string["project"]=campaign.clusters[cluster_id]["project"] if campaign.clusters[cluster_id]["project"]
       submission_string
    end

    # Add cigri environement variables to a submission string
    def add_cigri_variables(submission_string,campaign_id)
      cmd=submission_string["command"]
      vars= "export CIGRI_CAMPAIGN_ID=#{campaign_id};"
      submission_string["command"]=vars+cmd
      submission_string
    end

    # Submit a single job on the given cluster
    def submit_single_job(cluster,job,campaign,submission_string,tag=nil)
       # Add properties from the JDL
      submission_string=add_jdl_properties(submission_string,campaign,cluster.id,tag)
      submission_string=add_cigri_variables(submission_string,campaign.id)
      JOBLIBLOGGER.debug("Submitting new job on #{cluster.description["name"]}.")
      # Actual submission
      j=cluster.submit_job(submission_string,campaign.props[:grid_user])
      if j.nil?
        JOBLIBLOGGER.error("Unhandled error when submitting job on #{cluster.description["name"]}!")
      else
         # Update job info
         job.update(
                     { 'state' => 'submitted', 
                       'submission_time' => Time::now().to_s,
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
      submission_string=add_cigri_variables(submission_string,campaign.id)
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
                                 'submission_time' => Time::now().to_s,
                                 'cluster_id' => cluster.id,
                               },'jobs' )
        ids=launching_jobs.match_remote_ids(cluster.id, campaign.clusters[cluster.id]["exec_file"], j["id"])
        JOBLIBLOGGER.debug("Remote id of array job just submitted on #{cluster.description['name']}: #{j['id']}")
        return ids
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
        #TODO: treat walltime!
        if runner_options["besteffort"]
           submission_string["type"]="besteffort"
        end
      elsif runner_options["dimensional_grouping"]
         #TODO
      end
       # Add properties from the JDL
      submission_string=add_jdl_properties(submission_string,campaign,cluster.id)
      submission_string=add_cigri_variables(submission_string,campaign.id)
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
                                 'submission_time' => Time::now().to_s,
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
          tap=Cigri::Tap.new(:cluster_id => cluster_id, :campaign_id => campaign.id)
          tap.close
        # Cluster ok for this campaign
        else
          campaign.get_clusters
          # Select the jobs belonging to the current campaign
          myjobs=@records.select {|job| job.props[:campaign_id].to_i == campaign_id}
          # Treat prologue and epilogue jobs
          ["prologue","epilogue"].each do |tag|
            tagged_job=myjobs.select {|job| job.props[:tag] == tag}
            if tagged_job.length > 0
              submitted_jobs << submit_single_job(cluster,tagged_job[0],campaign,{
                               "resources" => "resource_id=1",
                               "name" => "cigri.#{campaign_id}",
                               "command" => campaign.clusters[cluster_id][tag] },tag )
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
	      JOBLIBLOGGER.debug("resources: "+campaign.clusters[cluster_id]["resources"].inspect)
              submission = {
                            "param_file" => params.join("\n"),
                            "resources" => campaign.clusters[cluster_id]["resources"],
                            "command" => campaign.clusters[cluster_id]["exec_file"],
                            "name" => "cigri.#{campaign_id}"
                           }
              if runner_options["besteffort"]
                submission["type"]="besteffort"
              end
              submitted_jobs = submitted_jobs + submit_array_job(cluster,jobs,campaign,submission)
            end
          end # Each runner option
        end # Blacklisted cluster
      end # Each campaign
      return submitted_jobs
    end

    # This function updates the "remote_id" field of the jobs. It matches
    # each job of a oar array_job with the corresponding cigri job.
    # For this, we ensure that the parameters part of the oar command is the same
    # of the param value in the cigri database.
    def match_remote_ids(cluster_id, command, array_id)
      ids=[]
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
        # we try to match the parameters of each job of the jobset
        index = jobs.index {|cigri_job| 
                    cluster_job["command"].split(/ /,2)[1].to_s.include?("#{cigri_job.props[:param]}")}
        if index
          cigri_job = jobs.delete_at(index)
          cigri_job.update({'remote_id' => cluster_job["id"]}, "jobs")
          ids << cluster_job["id"]
        else
          JOBLIBLOGGER.error("Could not find the CIGRI job corresponding to the OAR job #{cluster_job["id"]} !")
        end
      end
      return ids
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

    # Decrease the affinity of a task
    def decrease_affinity
      task=Datarecord.new("bag_of_tasks",:id => @props[:task_id])
      db_connect() do |dbh|
        if task.props.nil?
          # Too late... the task has probably been kept just before
        else
          decrease_task_affinity(dbh,task.props[:param_id],@props[:cluster_id])
        end
      end 
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
      to_jobs_tolaunch
    end

    # This method converts the Datarecord objects into Jobtolaunch objects
    def to_jobs_tolaunch
      jobs=[]
      @records.each do |record|
        props = record.props
        props[:nodb] = true
        job = Jobtolaunch.new(props)
        jobs << job
      end
      @records = jobs
    end

    # Alias to the dataset records
    def jobs
      @records
    end

    # Remove jobs from blacklisted campaigns
    def remove_blacklisted(cluster_id)
      new_records=[]
      blacklist={}
      cluster=Cluster.new(:id => cluster_id)
      campaigns.each do |campaign_id|
        blacklist[campaign_id]=true if cluster.blacklisted?(:campaign_id=>campaign_id) 
      end
      @records.each do |record|
        new_records << record if not blacklist[record.props[:campaign_id]]
      end
      @records=new_records
    end

    # Get jobs to launch on cluster cluster_id, with a limit per campaign
    # The tap hash contains the tap objects: open/closed and value of the 
    # max number of jobs to get (rate)
    def get_next(cluster_id,taps={})
      # Get the jobs order by priority
      jobs=get("jobs_to_launch,bag_of_tasks","*","cluster_id=#{cluster_id} 
                                                    AND task_id=bag_of_tasks.id
                                                    ORDER BY bag_of_tasks.priority DESC, order_num, jobs_to_launch.id")
      counts={}
      old_campaign_id=0
      cluster=Cluster.new(:id => cluster_id)
      # Check for blacklisted and paused campaigns
      campaigns_blacklist={}
      jobs.each {|j| campaigns_blacklist[j[:campaign_id].to_i]=false}
      campaigns_blacklist.each_key do |c|
        campaigns_blacklist[c]=true if cluster.blacklisted?(:campaign_id => c)
      end
      running_campaigns={}
      campaigns=Campaignset.new
      campaigns.get_running
      campaigns.each {|c| running_campaigns[c.id]=true }
      # We have to loop over each job, to check campaigns and taps
      jobs.each do |job|
        rate=0
        campaign_id=job[:campaign_id].to_i
        # Skip paused campaigns
        if running_campaigns[campaign_id].nil? or running_campaigns[campaign_id]!=true
          JOBLIBLOGGER.debug("Campaign #{campaign_id} is not running (paused?)")
          next
        end
        # Get the rate
        counts[campaign_id] ? counts[campaign_id]+=1 : counts[campaign_id]=1
        if not taps[campaign_id].nil?
          rate=taps[campaign_id].props[:rate].to_i
        end
        # If the tap is closed since a short time, dont' send jobs
        # to the runner. It causes the runner to wait a bit for jobs to start.
        if not taps[campaign_id].open? and 
             (Time::now().to_i - Time.parse(taps[campaign_id].props[:close_date]).to_i) < RUNNER_TAP_GRACE_PERIOD
           JOBLIBLOGGER.info("Waiting for tap grace period on cluster #{cluster_id} for campaign #{campaign_id}")
           break
        end
        # Only get jobs from a campaign having the tap open and not blacklisted
        if taps[campaign_id].open? and counts[campaign_id] <= rate and not campaigns_blacklist[campaign_id]
          # Get jobs from the first campaign only.
          # By this way, the runner does not send too much jobs from campaigns
          # having less priority: it only treats a campaign when there's no more
          # activity from the previous campaign.
          break if old_campaign_id != 0  and campaign_id != old_campaign_id
          job[:nodb]=true
          @records << Datarecord.new(@table,job) 
          old_campaign_id=campaign_id
        end
      end
      return self.length
    end

    # Take the jobs from the bag of tasks and return newly created jobs.
    # This is done in an atomical way to prevent from losing jobs in case of a 
    # crash. This is why we directly call an iolib function ithout using datarecords.
    def take
      check_connection!
      jobids=take_tasks(@@dbh,self.ids)
      if jobids.length > 0
        Jobset.new(:where => "jobs.id in (#{jobids.join(',')})")
      else
        JOBLIBLOGGER.debug("Failed to take tasks #{self.ids.inspect}. Maybe removed by nikita meantime?")
        return false
      end
    end

  end # Class JobtolaunchSet



  # Campaign class
  # A Campaign instance can be get from the database or newly created
  # See Datarecord class for more doc
  class Campaign < Datarecord
    attr_reader :props, :clusters

    # Creates a new campaign entry or get it from the database
    def initialize(props={})
      if not props[:jdl] and not props[:what]
        props[:what]="id,grid_user,state,type,name,submission_time,completion_time,nb_jobs"
        super("campaigns",props)
      else
        super("campaigns",props)
      end  
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
      return active_jobs_number > 0
    end

    # Return the number of active jobs
    def active_jobs_number
      db_connect() do |dbh|
        return get_campaign_active_jobs_number(dbh, id)
      end
    end

    # Return the number of active jobs on given cluster
    def active_jobs_number_on_cluster(cluster_id)
      db_connect() do |dbh|
        return get_campaign_active_jobs_number_on_cluster(dbh, id, cluster_id)
      end
    end

    # Get the number of queued jobs (jobs into jobs_to_launch table)
    def queued_jobs_number_on_cluster(cluster_id)
      db_connect() do |dbh|
        return get_campaign_queued_jobs_number_on_cluster(dbh, id,cluster_id)
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

    # Get events
    def events(limit, offset, all = 0)
      db_connect() do |dbh|
        return get_campaign_events(dbh, id, limit, offset, all)
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
      res=0
      db_connect do |dbh|
        res=get_campaign_throughput(dbh,id,time_window)
      end
      return res
    end

    # Get the failures rate
    # The failures rate is F/(F + T)
    #    F: failures count (number of jobs in the event state)
    #    T: number of terminated jobs
    def failures_rate
      res=0
      db_connect do |dbh|
        res=get_campaign_failures_rate(dbh,id)
      end
      return res
    end

    # Get the resubmit rate
    # The resubmit rate is R/(R + T)
    #    R: number of jobs automatically re-submitted by Cigri or Oar
    #    T: number of terminated jobs
    def resubmit_rate
      res=0
      db_connect do |dbh|
        res=get_campaign_resubmit_rate(dbh,id)
      end
      return res
    end

    # Construct runner options hash for the given cluster
    def get_runner_options(cluster_id)
      opts={}
      # Test mode is non-besteffort
      if @clusters[cluster_id]["test_mode"] == "true"
        opts[:besteffort] = false 
      # Campaign types
      else
        case @clusters[cluster_id]["type"]
        when "best-effort"
          opts[:besteffort] = true
        when "normal"
          opts[:besteffort] = false 
        else
          JOBLIBLOGGER.warn("Unknown campaign type: "+@clusters[cluster_id]["type"].to_s+"; using best-effort")
          opts[:besteffort] = true
        end
      end
      # Grouping
      if @clusters[cluster_id]["temporal_grouping"] == "true"
         opts["temporal_grouping"] = true
      elsif @clusters[cluster_id]["dimensional_grouping"] == "true"
         opts["dimensional_grouping"] = true
      end
      return opts
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
      finished_jobs = get_campaigns_nb_finished_jobs(@@dbh, ids)
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

    # Update the finished_jobs property of each campaign
    def compute_finished_jobs
      @records.each do |campaign|
        campaign.props[:finished_jobs] = campaign.nb_completed_tasks
      end
    end

    # Fill the campaignset with the currently running campaigns
    def get_running
      fill(get("campaigns","*","state = 'in_treatment'"))
      to_campaigns
    end
    
    # Fill the campaign set with unfinished campaigns (paused or running)
    def get_unfinished
      fill(get("campaigns","id,grid_user,state,type,name,submission_time,completion_time,nb_jobs","state IN ('in_treatment', 'paused')"))
      to_campaigns
    end

    # Returns a hash campaign_id => grid_user
    def get_users
      Hash[@records.map {|record| [record.id,record.props[:grid_user]]}]
    end

    # Return all the clusters (objects) that are used by at least
    ## Return all the clusters (objects) that are not blacklisted and used by at least
    # one campaign of this Campaignset
    # This is mainly to create a cache of cluster objects, for optimization
    def get_clusters
      clusters={}
      @records.each do |campaign|
        campaign.get_clusters
        campaign.clusters.each_key do |cluster_id|
          if not clusters[cluster_id]
            cluster=Cigri::Cluster.new(:id => cluster_id)
        #    if cluster.blacklisted?
        #      clusters[cluster_id]=nil
        #    else
              clusters[cluster_id]=cluster
        #    end
          end
        end
      end
      return clusters.values.compact
    end
  
    # Get a cluster from a cluster array (a clusters cache) by its id
    def get_cluster(cache,id)
      cache[cache.index {|c| c.id == id}]
    end

    # Get campaign by its id
    def get_campaign(id)
      @records.each do |campaign|
        return campaign if campaign.id==id
      end
      JOBLIBLOGGER.error("Campaign #{id} not found in current campaignset!")    
    end

    # Compute an ordered list of (campaign_id,cluster_id) on which we can schedule jobs
    # This is the main metascheduler method.
    # The order defines the priority for scheduling.
    # The presence of a couple is conditionned by blacklists, prologue and stress_factor.
    # The order depends on users_priority and test_mode.
    def compute_campaigns_orders
      couples=[]
      clusters_cache=get_clusters
      test_campaigns={}
      max={}
      # First pass: get the active couples (remove blacklisted and under stress clusters)
      # Also record the test campaigns for future prioritisation
      @records.each do |campaign|
        campaign.get_clusters
        campaign.clusters.each_key do |cluster_id|
          cluster=get_cluster(clusters_cache,cluster_id)
          if campaign.prologue_ok?(cluster_id) and 
               not cluster.blacklisted? and 
               not cluster.under_stress?
             couple = [cluster_id.to_i,campaign.id.to_i]
             couples << couple
             if campaign.clusters[cluster_id]["test_mode"] == "true"
               test_campaigns[couple]=true
               campaign.clusters[cluster_id]["max_jobs"]=1
             else 
               test_campaigns[couple]=false
             end
             #Compute the max number of jobs to queue (a function of running, queued and test)
             active_jobs=campaign.active_jobs_number_on_cluster(cluster_id)
             queued_jobs=campaign.queued_jobs_number_on_cluster(cluster_id)
             n_jobs=active_jobs + queued_jobs
             if campaign.clusters[cluster_id]["max_jobs"]
               max[couple]=campaign.clusters[cluster_id]["max_jobs"].to_i - n_jobs
             else
               max[couple]=nil
             end
             #Limit max depending on taps
             tap=Cigri::Tap.new(:cluster_id => cluster_id.to_i, :campaign_id => campaign.id.to_i)
             max_to_queue=tap.props[:rate].to_i*10 - queued_jobs
             max_to_queue=0 if max_to_queue < 0
             if max[couple].nil? or max[couple] == nil or max_to_queue < max[couple]
               max[couple]=max_to_queue
             end
             JOBLIBLOGGER.debug("CA=#{campaign.id} CL=#{cluster_id} N=#{n_jobs} (#{active_jobs} active, #{queued_jobs} queued) max=#{max[couple]}")
          end
          
        end
      end
      # Second pass: order the couples by users affinity and fifo
      users=get_users
      sorted_couples=[]
      clusters_cache.sort{|a,b| a.props[:power] <=> b.props[:power]}
      clusters_cache.each do |cluster|
        # TODO: Any way to do the following two lines in one shot?
        campaigns=couples.select{|c| c[0]==cluster.id}
        campaigns.map!{|c| c[1].to_i }
        # Get users priority
        users_priority=Dataset.new('users_priority',:where => "cluster_id = #{cluster.id}")
        priorities={}
        campaigns.each do |campaign_id|
          p=users_priority.records.select{|u| u.props[:grid_user] == users[campaign_id]}[0]
          if p
            priorities[campaign_id]=p.props[:priority].to_i
          else
            priorities[campaign_id]=0
          end
        end
        # Do a stable sort on priorities (stable for ids)
        campaigns=campaigns.sort_by{|x| [priorities[x]*-1,x]}
        # Create the couples, test campaigns first (yes, this is again a sort pass, for test mode this time)
        campaigns.each do |campaign_id|
          couple=[cluster.id.to_i,campaign_id]
          if test_campaigns[couple] == true
            sorted_couples << couple
            campaigns.delete(campaign_id)
          end
        end
        campaigns.each do |campaign_id|
          sorted_couples << [cluster.id.to_i,campaign_id]
        end
      end

      # return the couples plus the third "max" element
      return sorted_couples.map{|c| [c[0],c[1],max[c]]}
    end
 
  # Computes an ordered list of tasks for a given campaign on a given cluster
  # and stop when max tasks are stacked.
  # This is the main method for the scheduler-affinity.
  # This takes tasks_affinity into account for sorting. 
  # Returns an array of bag_of_tasks ids
  # Warning: this is not a list of tasks to execute! This is just for ordering. This
  # is a list of tasks that may potentially be run on the cluster. It does not
  # guaranty unicity: same tasks may be given for another cluster, but in a
  # different order (or not!)
  def compute_tasks_list(cluster_id,campaign_id,max=nil)
    check_connection!
    get_tasks_ids_for_campaign_on_cluster(@@dbh,campaign_id,cluster_id,max)
  end

  end # Class Campaignset
  
end # module Cigri
