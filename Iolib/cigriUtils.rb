# Utility cigri ruby functions

# Connect to the database
#
def base_connect(dbname_host,login,passwd)
  return DBI.connect("dbi:Mysql:#{dbname_host}",login,passwd)
end

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

# Lock the collector
#
def lock_collector(dbh,time)
  dbh.select_all("SELECT GET_LOCK(\"cigriCollectorLock\",#{time})")
end

# Unlock the collector
#
def unlock_collector(dbh)
  dbh.select_all("SELECT RELEASE_LOCK(\"cigriCollectorLock\")")
end

# Create a new collect
#
def new_collect_id(dbh,mjobid)
  query = "SELECT MAX(collectedJobsId) as id FROM collectedJobs WHERE collectedJobsMJobsId = #{mjobid}"
  result=dbh.select_all(query)
  result[0]['id'].to_i+1
end
  

