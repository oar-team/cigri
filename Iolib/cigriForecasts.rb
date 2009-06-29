
# Ruby definitions of forecasts associated to MultipleJobs (or campaigns)

#########################################################################
# Forecasts class
#########################################################################
class Forecasts

	attr_reader :mjobid, :mjob, :throughput, :average, :stddev, :lastjobratio, :jobratio

	# Creation
	def initialize(mjob)
		@mjob = mjob
		@mjobid = mjob.mjobid.to_i

		@average, @stddev = get_average
		if get_conf("TIME_WINDOW_SIZE")
			$time_window_size=get_conf("TIME_WINDOW_SIZE").to_i
		else
			$time_window_size=3600
		end
		@throughput = get_throughput($time_window_size);
	end

	# get average job duration 
	# returns: [duration, stddev]
 	def get_average
        if !mjob.durations.empty?
             std_dev = mjob.durations.first **2
             total = mjob.durations.inject {|sum, d| std_dev += d * d; sum + d }
             n = mjob.durations.length.to_f
             mean = total.to_f / n
             std_dev = Math.sqrt(std_dev.to_f / n - mean **2)
             return [mean,std_dev]
        else
            return [0.0,0.0]
        end
        	return [0.0,0.0]
    end

	#get job throughput in near past (sliding window)
 	def get_throughput(time_window_size)
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
	def self.forecast_average(mjob)
    	if mjob.n_running != 0
			avg =  Forecasts.new(mjob).get_average[0]
			#print "average = #{avg}\n"
			#print "waiting = #{mjob.n_waiting}\n"
			#print "running = #{mjob.n_running}\n"

        	return ( ((mjob.n_waiting.to_f + mjob.n_running.to_f/2) * avg) / mjob.n_running.to_f).to_i
    	else
        	return 0
    	end
 	end

 
	 # Make a forecast based on the job throughput in the last window seconds
	 # Returns a number of seconds
 	def self.forecast_throughput(mjob,window)
    	throughput=Forecasts.new(mjob).get_throughput(window)
		#print "throughput = #{throughput}\n"
		#print "waiting = #{mjob.n_waiting}\n"
		#print "running = #{mjob.n_running}\n"
    	if throughput != 0
			a=( (mjob.n_waiting.to_f + mjob.n_running.to_f/2) / throughput ).to_i
			puts "--- #{a}"
        	return ( (mjob.n_waiting.to_f + mjob.n_running.to_f/2) / throughput ).to_i
     	else
        	return 0
    	end
	end
 
 
	def to_s
	   summary = sprintf("Forecasts:
        Throughput (last hour):  %.2f jobs/hour 
        Average:                 %i s 
        Stddev:                  %.2f", \
		(@throughput * 3600), @average, @stddev)
		
	   return summary

	end


end 	
