
# Ruby definitions of forecasts associated to MultipleJobs (or campaigns)

#########################################################################
# Forecasts class
#########################################################################
class Forecasts

	attr_reader :mjobid, :mjob, :throughput, :global_throughput, :average, :global_average, :stddev, :global_stddev, :lastjobratio, :jobratio


	# Creation
	def initialize(mjob)
		@mjob = mjob
		@mjobid = mjob.mjobid.to_i

		@average, @stddev = get_average_by_cluster
		@global_average, @global_stddev = get_global_average

		if get_conf("TIME_WINDOW_SIZE")
			$time_window_size=get_conf("TIME_WINDOW_SIZE").to_i
		else
			$time_window_size=3600
		end
		
		@throughput = get_throughput_by_cluster($time_window_size);
		@global_throughput = get_global_throughput($time_window_size);
	end


	# get average job duration 
    # returns: [duration, stddev]
    def get_global_average
        return [nil,nil] if mjob==nil
        if !mjob.durations.empty?
			 mean = (mjob.durations.inject {|sum, d| sum + d}.to_f)/mjob.durations.length
             std_dev = Math.sqrt(mjob.durations.inject(0){|sum, dif| sum + ((dif-mean)**2)}.to_f/mjob.durations.length)

             return [mean,std_dev]
        else
            return [0.0,0.0]
        end
            return [0.0,0.0]
    end

	# get average job duration by cluster
	# returns: [duration, stddev]
 	def get_average_by_cluster
		
        return [nil,nil] if mjob==nil

		duration_hash = Hash.new
		clusters_avg = Hash.new
		clusters_stddev =  Hash.new
		
        if !mjob.durations.empty?
			mjob.jobs.each do |job|
				if !duration_hash.has_key?(job.cluster)
					duration_hash[job.cluster] = Array.new
				end

				duration_hash[job.cluster].push(job.duration)
				#puts "push #{job.duration} for #{job.jid}"
			end
		end

		duration_hash.each_pair do |cluster, durations|
			 clusters_avg[cluster] =  (durations.inject {|sum, d| sum + d}.to_f)/durations.length 
			
			clusters_stddev[cluster] =  Math.sqrt(durations.inject(0){|sum, dif| sum + ((dif-clusters_avg[cluster])**2)}.to_f/durations.length)
		end

		return [clusters_avg,clusters_stddev]

    end

	#get global mjob throughput in near past (sliding window)
 	def get_throughput_by_cluster(time_window_size)
        return nil if mjob==nil

		throughput_hash = Hash.new
		tsub_hash = Hash.new
		terminated_hash = Hash.new

		if (mjob.status == 'TERMINATED')
			mjob.jobs.each do |job|
				if !throughput_hash.has_key?(job.cluster)
            		throughput_hash[job.cluster] = 0
            		terminated_hash[job.cluster] = 0
            	end		
				terminated_hash[job.cluster]+=1	
			end
			throughput_hash.each_key do |cluster|
				throughput_hash[cluster] = terminated_hash[cluster].to_f/mjob.duration
			end
			return throughput_hash 

		else 
        	mjob.jobs.each do |job|
				if !throughput_hash.has_key?(job.cluster)                    
					tsub_hash[job.cluster] = Time.now.to_i
                    throughput_hash[job.cluster] = 0
                    terminated_hash[job.cluster] = 0
                end
        		if job.state == 'Terminated' && job.tsub > (Time.now - time_window_size).to_i
                	terminated_hash[job.cluster] += 1
                 	tsub_hash[job.cluster] = job.tsub if job.tsub < tsub_hash[job.cluster]
             	end
         	end
		
			throughput_hash.each_key do |cluster|
				if terminated_hash[cluster] != 0
					throughput_hash[cluster] = terminated_hash[cluster].to_f / (Time.now.to_i - tsub_hash[cluster])
         			puts "Calculated troughtput on cluster #{cluster}: #{throughput_hash[cluster]} (#{throughput_hash[cluster]*3600} j/h) - #{terminated_hash[cluster]} jobs during window" if $verbose
				else
					throughput_hash[cluster] = nil
				end
        	end
		end
		return throughput_hash
     end


	#get job throughput by cluster (a hash) in near past (sliding window)
 	def get_global_throughput(time_window_size)
         return nil if mjob==nil


         return mjob.n_terminated.to_f/mjob.duration.to_f if mjob.status == 'TERMINATED'
         n=0
         first_submited_date = Time.now.to_i
         mjob.jobs.each do |job|
             if job.state == 'Terminated' && job.tsub > (Time.now - time_window_size).to_i
                 n+=1
                 first_submited_date = job.tsub if job.tsub < first_submited_date
             end
         end
         if n != 0
         t = n.to_f / (Time.now.to_i - first_submited_date).to_f
         puts "Calculated troughtput: #{t} (#{t*3600} j/h) - #{n} jobs during  window" if $verbose
             return t
         else
             return 0.0
         end
     end

 

	# make a forecast based on the average job duration and number 
	# of currently running jobs. Returns a number of seconds
	def get_forecast_average
    	if mjob.n_running != 0
			avg = get_global_average[0]

        	return ( ((mjob.n_waiting.to_f + mjob.n_running.to_f/2) * avg) / mjob.n_running.to_f).to_i
    	else
        	return 0
    	end
 	end


	def self.forecast_average(mjob)
    	if mjob.n_running != 0
			avg = Forecasts.new(mjob).get_global_average[0]

        	return ( ((mjob.n_waiting.to_f + mjob.n_running.to_f/2) * avg) / mjob.n_running.to_f).to_i
    	else
        	return 0
    	end
 	end

 
	# Make a forecast based on the job throughput in the last window seconds
	# Returns a number of seconds
	def get_forecast_throughput(window)
    	throughput = get_global_throughput(window)
    	
		if throughput != 0
			a=( (mjob.n_waiting.to_f + mjob.n_running.to_f/2) / throughput ).to_i
        	return ( (mjob.n_waiting.to_f + mjob.n_running.to_f/2) / throughput ).to_i
     	else
        	return 0
    	end
	end


 	def self.forecast_throughput(mjob,window)
    	throughput=Forecasts.new(mjob).get_global_throughput(window)
    	
		if throughput != 0
			a=( (mjob.n_waiting.to_f + mjob.n_running.to_f/2) / throughput ).to_i
        	return ( (mjob.n_waiting.to_f + mjob.n_running.to_f/2) / throughput ).to_i
     	else
        	return 0
    	end
	end
 

	#TODO emathias, exchange cluster by full and create a full version 
	def to_s
	   summary = sprintf("Forecasts:
        Throughput (last hour):  %.2f jobs/hour 
        Average:                 %i s 
        Stddev:                  %.2f", \
		(@global_throughput * 3600), @global_average, @global_stddev)
		
	   return summary
	end

    def to_s_full
       summary = sprintf("Forecasts:
        Global Throughput (last hour):  %.2f jobs/hour 
        Global Average:                 %i s 
        Global Stddev:                  %.2f", \
        (@global_throughput * 3600), @global_average, @global_stddev)

		throughput.each_key do |cluster|
			if (@throughput[cluster] != nil)
	   			summary += sprintf("\n\n%s:
        Throughput (last hour):  %.2f jobs/hour 
        Average:                 %i s 
        Stddev:                  %.2f", \
       			cluster, (@throughput[cluster] * 3600), @average[cluster], @stddev[cluster]) 
	   		end
		end 

		return summary
    end
	


end 	
