
# Ruby definitions of jobs and multijobs

#########################################################################
# Job class
#########################################################################
class Job
    attr_reader :jid, :mjobid, :state, :tsub, :tstart, :tstop, :param, :cluster, :batchid, :node, :cdate, :cstatus

    # Creation
    def initialize(id,mjobid,state,tsub,tstart,tstop,param,cluster,batchid,node,cdate,cstatus)
        @jid=id
        @mjobid=mjobid
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
        sprintf "Job #{@jid}: #{@mjobid},#{@state},#{@tsub},#{@tstart},#{@tstop}"
    end

    # Calculate the job duration (from submission to end or now)
    def duration
        if state == 'Terminated'
            return tstop - tstart
        else
            return Time.now.to_i - tstart
        end
     end
end

#########################################################################
## JobSet class
# A JobSet is a set of jobs resulting of an SQL query on the jobs table
#########################################################################
class JobSet
    attr_reader :jobs

    def initialize(dbh,query)
        if query.empty? 
	  raise "Cannot create a jobset without a request"
	end
        @dbh=dbh
        @query=query
        @jobs=[]
    end

    def do
        sql_jobs=@dbh.select_all(@query)
        sql_jobs.each do |sql_job|
             job=Job.new(sql_job['jobId'],\
                        sql_job['jobMJobsId'],\
                        sql_job['jobState'],\
                        to_unix_time(sql_job['jobTSub']),\
                        to_unix_time(sql_job['jobTStart']),\
                        to_unix_time(sql_job['jobTStop']),\
                        sql_job['jobParam'],\
                        sql_job['jobClusterName'],\
                        sql_job['jobBatchid'],\
                        sql_job['jobNodeName'],\
                        sql_job['jobCheckpointDate'],\
                        sql_job['jobCheckpointStatus'])
            @jobs << job
	end
    end

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
        jobs.each do |job|
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

# Convert a MySQL date into a unix timestamp
#
def to_unix_time(time)
    if time.nil?
      return 0
    else
      year, month, day, hour, minute, sec = time.to_s.split(/ |:|-/)
      unix_sec = Time.local(year, month, day, hour, minute, sec).to_i
      return unix_sec
    end
end

# Convert a time into number of seconds
#
def hmstos(hms)
    h,m,s = hms.to_s.split(/:/)
    return 3600*h.to_i + 60*m.to_i + s.to_i
end

# Convert a number of seconds into a duration in days, hours and minutes
#
def stodhm(s)
    d = s/(24*3600)
    s -= d * (24*3600)
    h = s / 3600
    m = (s- h * 3600) / 60
    return "#{d} days #{h}:#{m}"
end

# Connect to the database
#
def base_connect(dbname_host,login,passwd)
    return DBI.connect("dbi:Mysql:#{dbname_host}",login,passwd)
end

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

