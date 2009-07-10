
# Ruby definitions of jobs and multijobs

#########################################################################
# Job class
#########################################################################
class Job
    attr_reader :jid, :mjobid, :name, :state, :tsub, :tstart, :tstop, :param, :cluster, :batchid, :node, :cdate, :cstatus 
    attr_accessor :ctype, :cperiod, :user, :localuser, :active, :batchtype, :execdir

    # Creation
    def initialize(*args)
        case args.length
        # If only one argument, then it is the result of an sql query
        when 1
          fill(args[0])
        # If no argument, an empty object with id 0 is created
        when 0
          @jid=0
        # Else, we initialize with the provided values
        when 13 
	 (@jid,@mjobid,@name,@state,@tsub,@tstart,@tstop,@param,\
	   @cluster,@batchid,@node,@cdate,@cstatus)=args

		#puts  " #{@jid} #{@mjobid} #{@state} #{@tsub} #{@tstart} #{@tstop}"
        else
          raise("Wrong number of arguments for initialize")
        end
    end

    # Fill the attributes with the provided result of an sql query
    def fill(sql_job)
        initialize(sql_job['jobId'],\
                   sql_job['jobMJobsId'],\
                   sql_job['jobName'],\
                   sql_job['jobState'],\
                   to_unix_time(sql_job['jobTSub']),\
                   to_unix_time(sql_job['jobTStart']),\
                   to_unix_time(sql_job['jobTStop']),\
                   sql_job['jobParam'],\
                   sql_job['jobClusterName'],\
                   sql_job['jobBatchId'],\
                   sql_job['jobNodeName'],\
                   to_unix_time(sql_job['jobCheckpointDate']),\
                   sql_job['jobCheckpointStatus'])
        # Update extended attributes if the query gives the needed results
        # (else the accessor will be 'nil')
        @ctype=sql_job['propertiesCheckpointType']
        @cperiod=sql_job['propertiesCheckpointPeriod']
        @user=sql_job['MJobsUser']
        @batchtype=sql_job['clusterBatch']
        @execdir=sql_job['propertiesExecDirectory']
        @localuser=sql_job['userLogin']
    end

    # Printing
    def to_s
        sprintf "Job #{@jid}: #{@mjobid},#{@cluster},#{@state},#{@tsub},#{@tstart},#{@tstop},#{@user},#{@batchid},#{@active}"
    end

    # Calculate the job duration (from submission to end or now)
    def duration
        if state == 'Terminated'
            return tstop - tstart
        elsif state == 'Event'
			return 0
		else
			# tstart = 0 means job is Running, but not started by RM
			if (tstart == 0)
				return 0
			else
            	return Time.now.to_i - tstart
			end
        end
     end

     # Sets the checkpoint date of the job
     def update_checkpoint_date(dbh,unix_timestamp)
         @cdate=unix_timestamp
         query="UPDATE jobs set jobCheckpointDate=FROM_UNIXTIME(#{@cdate}) WHERE jobId=#{@jid}"
         dbh.do(query)
     end

end

#########################################################################
## JobSet class
# A JobSet is a set of jobs resulting of an SQL query on the jobs table
#########################################################################
class JobSet
    attr_reader :jobs

    def initialize(dbh,query,init=false)
        if query.empty? 
	  raise "Cannot create a jobset without a request"
	end
        @dbh=dbh
        @query=query
        @jobs=[]
	if init
          self.do
	end
    end

    def each
        @jobs.each {|j| yield(j)}
    end

    # Execute the query and create the jobs of the jobset
    def do
        sql_jobs=@dbh.select_all(@query)
        sql_jobs.each do |sql_job|
            job=Job.new(sql_job)
            @jobs << job
	end
    end

    # Update the "active" attribute for all the jobs in this JobSet
    # (SQL optimized) 
    def update_active
      # Firstly, we initialize a hash of hashes to get (mjobid,clusters) couples
      # This will prevent from doing the same request several times 
      active={}
      @jobs.each do |job|
        active[job.mjobid] ={} if active[job.mjobid].nil?
        active[job.mjobid][job.cluster]=0
      end
      # Then, we update the hash with the status of the clusters from the database
      active.each do |mjobid,clusters|
        clusters.each_key do |cluster|
	  query="SELECT count( * ) as n\
              FROM clusterBlackList, events \
	      WHERE clusterBlackListEventId = eventId \
	      AND eventState = \"ToFIX\" \
	      AND clusterBlackListClusterName = \"#{cluster}\" \
	      AND (clusterBlackListMJobsID = #{mjobid} \
	      OR clusterBlackListMJobsID = 0)"
	  if @dbh.select_all(query)[0]['n'].to_i == 0
	    active[mjobid][cluster]=1
	  else
	    active[mjobid][cluster]=0
	  end
	end
      end
      # Finaly, we update the "active" field of each job
      @jobs.each do |job|
        job.active=active[job.mjobid][job.cluster]
      end
    end

    # Filter the jobs by removing those on a blacklisted cluster
    # (This has to be a Colombo feature)
    def remove_blacklisted
      update_active
      newjobs=[]
      @jobs.each do |job|
        newjobs << job if job.active == 1
      end
      @jobs=newjobs
    end

    # Printing (mainly used for debug)
    def to_s
      @jobs.each { |j| sprintf j.to_s + "\n" }
    end

end


#########################################################################
# MultipleJob class
#########################################################################


class MultipleJob < JobSet
    attr_reader :mjobid, :type, :jobs, :last_terminated_date, :status, :n_running, :n_terminated, :durations

    # Creation
    def initialize(dbh,id)
        super(dbh,"SELECT * FROM jobs WHERE jobMJobsId=#{id}")
	self.do
        @dbh=dbh
        @mjobid=id
        @durations=[]
        @last_terminated_date=0
        @first_submited_date=0
        @n_running=0
        @n_terminated=0
        @n_trans=0

        # Status of this multiple job
        query = "SELECT MJobsState, MJobsType, MJobsTSub FROM multipleJobs where MJobsId=#{mjobid}"
        sql_mjob=dbh.select_all(query)
	if sql_mjob.empty?
	    raise "Could not find multiplejob #{mjobid}"
	end
        @status=sql_mjob[0]['MJobsState']
        @type=sql_mjob[0]['MJobsType']
        @tsub=to_unix_time(sql_mjob[0]['MJobsTSub'])

        # Get the blacklisted clusters for this job
	query = "SELECT clusterBlackListClusterName \
	         FROM clusterBlackList, events \
		 WHERE clusterBlackListEventId = eventId \
		   AND eventState = \"ToFIX\" AND clusterBlackListMJobsID = #{mjobid};"
        bl_clusters=dbh.select_all(query)

        # Job parsing to get some statistics
        @jobs.each do |job|
            case job.state
                when  'Terminated'
                    # Get the date of the last terminated job and the number of terminated jobs
                    @last_terminated_date = job.tstop if @last_terminated_date < job.tstop
                    @n_terminated+=1

                    # Make an array of jobs durations
                    @durations << job.duration

                when 'Running'
                    # Get the number of running jobs
		    bl=1
		    bl_clusters.each do |bl_cluster|
		      if bl_cluster['clusterBlackListClusterName'] == job.cluster
		        bl=nil
	              end
		    end
                    @n_running+=1 if bl
                when 'toLaunch', 'RemoteWaiting'
                    # Get the number of jobs in a transitional status
                    @n_trans+=1
            end

            # Get the date of the first submited job
            @first_submited_date = job.tsub if @first_submited_date > job.tsub
        end
    end

    # Number of waiting parameters
    def n_waiting
        query = "SELECT count(*) as n FROM parameters WHERE parametersMJobsId=#{@mjobid}"
        return @dbh.select_all(query)[0]['n'].to_i + @n_trans
    end

    # Duration of this multiple job
    def duration
        return Time.now.to_i - @tsub if @status != 'TERMINATED'
        return @last_terminated_date - @tsub else 
    end

    # Printing
    def to_s
        sprintf("Multiple job %i
        Type:                   %s 
        Status:                 %s
        Submited:               %s
        Last terminated job:    %s 
        Running:                %i 
        Waiting:                %i 
        Terminated:             %i 
        Duration:               %i s", \
        @mjobid,@type,@status,Time.at(@tsub),Time.at(@last_terminated_date),@n_running,n_waiting,@n_terminated,duration)
    end
end

#########################################################################
# Functions
#########################################################################

# Returns the running jobs that may be checkpointed (array of job objects)
#
def get_checkpointable_jobs(dbh)
    query="SELECT * FROM jobs,properties,multipleJobs \
       WHERE jobState='Running' \
       AND jobs.jobMJobsId=properties.propertiesMJobsId
       AND jobs.jobMJobsId=multipleJobs.MJobsId
       AND propertiesCheckpointType is not null
       AND not propertiesCheckpointType = ''
       ORDER BY jobClusterName"
    jobset=JobSet.new(dbh,query)
    jobset.do
    # Filter with blacklisted clusters
    jobset.remove_blacklisted
    return jobset.jobs
end

# Get the multiple jobs to collect
# Returns an array of MultipleJob objects
def tocollect_MJobs(dbh)
  mjobs=[]
  query="   SELECT jobMJobsId, COUNT( * )
            FROM jobs
            WHERE jobState = \"Terminated\"
            AND jobCollectedJobId = 0
            GROUP BY jobMJobsId
        "
  dbh.select_all(query).each do |result|
    mjobs << MultipleJob.new(dbh,result['jobMJobsId'])
  end
  mjobs
end

# Get the jobs to collect
# Returns a JobSet object
def tocollect_Jobs(dbh)
  JobSet.new(dbh,"SELECT jobId,jobClusterName,jobMJobsId,jobName,jobBatchId,
                         MJobsUser,clusterBatch,propertiesExecDirectory,userLogin
                  FROM jobs,multipleJobs,clusters,properties,users
                  WHERE jobState = \"Terminated\" 
                  AND jobCollectedJobId = 0
		  AND jobMJobsId=mJobsId
		  AND jobClusterName=clusterName
		  AND propertiesMJobsId=jobMJobsId
		  AND propertiesClusterName=clusterName
		  AND userGridName=MJobsUser
		  AND userClusterName=jobClusterName
		  ORDER by jobMJobsId,jobClusterName",true)
end

def set_collected_job(dbh,jobid,collectid)
  query="UPDATE jobs SET jobCollectedJobId = #{collectid} where jobId = #{jobid}"
  dbh.execute(query)
end
