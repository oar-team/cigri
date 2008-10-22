
# Ruby definitions of jobs and multijobs

#########################################################################
# Job class
#########################################################################
class Job
    attr_reader :jid, :mjobid, :name, :state, :tsub, :tstart, :tstop, :param, :cluster, :batchid, :node, :cdate, :cstatus 
    attr_accessor :ctype, :cperiod, :user, :localuser, :active, :batchtype, :execdir

    # Creation
    def initialize(id,mjobid,name,state,tsub,tstart,tstop,param,cluster,batchid,node,cdate,cstatus)
        @jid=id
        @mjobid=mjobid
        @name=name
        @state=state
        @tsub=tsub
        @tstart=tstart
        @tstop=tstop
	@param=param
	@cluster=cluster
	@batchid=batchid
	@node=node
	@cdate=cdate
	@cstatus=cstatus
    end

    # Printing
    def to_s
        sprintf "Job #{@jid}: #{@mjobid},#{@cluster},#{@state},#{@tsub},#{@tstart},#{@tstop},#{@user},#{@batchid},#{@active}"
    end

    # Calculate the job duration (from submission to end or now)
    def duration
        if state == 'Terminated'
            return tstop - tstart
        else
            return Time.now.to_i - tstart
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

    # Execute the query and update the jobs of the jobset
    def do
        sql_jobs=@dbh.select_all(@query)
        sql_jobs.each do |sql_job|
             job=Job.new(sql_job['jobId'],\
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
	     job.ctype=sql_job['propertiesCheckpointType']
	     job.cperiod=sql_job['propertiesCheckpointPeriod']
	     job.user=sql_job['MJobsUser']
	     job.batchtype=sql_job['clusterBatch']
	     job.execdir=sql_job['propertiesExecDirectory']
	     job.localuser=sql_job['userLogin']
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
    attr_reader :mjobid, :jobs, :last_terminated_date, :status, :n_running, :n_terminated

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
        query = "SELECT MJobsState, MJobsTSub FROM multipleJobs where MJobsId=#{mjobid}"
        sql_mjob=dbh.select_all(query)
	if sql_mjob.empty?
	    raise "Could not find multiplejob #{mjobid}"
	end
        @status=sql_mjob[0]['MJobsState']
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

    # Job throughput during the time window
    def throughput(time_window_size)
        return @n_terminated.to_f/duration.to_f if @status == 'TERMINATED'
        n=0
        first_submited_date = Time.now.to_i
        @jobs.each do |job|
            if job.state == 'Terminated' && job.tsub > (Time.now - time_window_size).to_i
                n+=1
                first_submited_date = job.tsub if job.tsub < first_submited_date
            end
        end
        if n != 0
	    t = n.to_f / (Time.now.to_i - first_submited_date).to_f
	    puts "Calculated troughtput: #{t} (#{t*3600} j/h) - #{n} jobs during window" if $verbose 
            return t
        else
            return 0.0
        end
    end

    # Mean and stddev duration of terminated jobs
    def average
        if !@durations.empty?
            std_dev = @durations.first **2
            total = @durations.inject {|sum, d| std_dev += d * d; sum + d }
            n = @durations.length.to_f
            mean = total.to_f / n
            std_dev = Math.sqrt(std_dev.to_f / n - mean **2)
            return [mean,std_dev]
        else
            return [0.0,0.0]
        end
    end

    # Printing
    def to_s
        sprintf("Multiple job %i 
        Status:                 %s
        Submited:               %s
        Last terminated job:    %s 
        Running:                %i 
        Waiting:                %i 
        Terminated:             %i 
        Troughput (last hour):  %.2f jobs/hour 
        Duration:               %i s 
        Average:                %i s 
        Stddev:                 %.2f", \
        @mjobid,@status,Time.at(@tsub),Time.at(@last_terminated_date),@n_running,n_waiting,@n_terminated,\
	throughput(3600)*3600,duration,average[0].to_i,average[1])
    end
end

#########################################################################
# Functions
#########################################################################

# Make a forecast based on the average job duration and number 
# of currently running jobs. Returns a number of seconds
def forecast_average(mjob)
    if mjob.n_running != 0 
        return ( ((mjob.n_waiting + mjob.n_running/2) * mjob.average[0]) / mjob.n_running ).to_i
    else
        return 0
    end
end

# Make a forecast based on the job throughput in the last window seconds
# Returns a number of seconds
def forecast_throughput(mjob,window)
    throughtput=mjob.throughput(window)
    if throughtput != 0
        return ( (mjob.n_waiting + mjob.n_running/2) / throughtput ).to_i
    else
        return 0
    end
end

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
