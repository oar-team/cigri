
# Ruby definitions of events

#########################################################################
# Cluster class
#########################################################################
class Event
  attr_accessor :eid, :type, :class, :state, :jobid, :cluster,  :mjobid, :date, :message, :adminnote
#OLDSCHED------------------------------------------
#   attr_accessor :eid, :type, :class, :state, :jobid, :cluster, :schedulerid, :mjobid, :date, :message, :adminnote
#-------------------------------------------------- 

  # Creation
  def initialize(*args)
    case args.length
    # If only one argument, then it is the result of an sql query
    when 1
      fill(args[0])
    # If no argument, a new event with id 0 is created
    when 0
      @eid=0
      @state="ToFIX"
      @date=Time.now.strftime("%Y-%m-%d %H:%M:%S")
      @jobid=0
      @jobid=0
      @schedulerid=0
    # Else, we initialize with the provided values
#OLDSCHED------------------------------------------
#     when 11
#       (@eid,@type,@class,@state,@jobid,@cluster,@schedulerid,\
#        @mjobid,@date,@message,@adminnote)=args
#-------------------------------------------------- 
	 when 10
      (@eid,@type,@class,@state,@jobid,@cluster,\
       @mjobid,@date,@message,@adminnote)=args

    else
      raise("Wrong number of arguments for initialize")
    end
  end

  def fill(sql_res)
    initialize(sql_res['eventId'],\
               sql_res['eventType'],\
	       sql_res['eventClass'],\
	       sql_res['eventState'],\
	       sql_res['eventJobId'],\
	       sql_res['eventClusterName'],\
	       sql_res['eventSchedulerId'],\
	       sql_res['eventMJobsId'],\
	       sql_res['eventDate'],\
	       sql_res['eventMessage'],\
	       sql_res['eventAdminNote'])
  end

  def to_s
    sprintf "Event #{@eid}: #{@date},#{@type},#{@class},#{@state}\n  #{@message}"
  end

  def insert(dbh)
	#OLDSCHED------------------------------------------
    #query="INSERT INTO events
    #       (eventType,eventClass,eventState,eventJobId,eventClusterName,
	#     eventSchedulerId,eventMJobsId,eventDate,eventMessage)
	#    VALUES
	#    ('#{@type}','#{@class}','#{@state}','#{@jobid}','#{cluster}',
	#     '#{@schedulerid}','#{@mjobid}','#{@date}','#{message}')
	#   "
	#-------------------------------------------------- 
    query="INSERT INTO events
           (eventType,eventClass,eventState,eventJobId,
		eventClusterName,eventMJobsId,eventDate,eventMessage)
	   VALUES
	   ('#{@type}','#{@class}','#{@state}','#{@jobid}','#{cluster}',
		'#{@mjobid}','#{@date}','#{message}')
	  "

    dbh.execute(query)
  end

end

##### FUNCTIONS

# Use the perl Colombo lib for the moment
def check_events(dbh)
  return system(File.dirname($0)+"/../Colombo/checkEvents.pl")
end

# Add a new cluster event and check it
def add_new_cluster_event(dbh,cluster,mjobid,type,message)
  e=Event.new()
  e.type=type
  e.class="CLUSTER"
  e.cluster=cluster
  e.mjobid=mjobid
  e.message=message
  e.insert(dbh)
  check_events(dbh)
end

