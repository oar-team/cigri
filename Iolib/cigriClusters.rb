
# Ruby definitions of clusters

#########################################################################
# Cluster class
#########################################################################
class Cluster
  attr_reader :name

  # Creation
  def initialize(dbh,name)
    @dbh=dbh
    @name=name
  end

  # Status
  # If no mjobid, it is the global status
  def active?(mjobid=0)
    query = "SELECT count( * ) as count
                 FROM clusterBlackList, events
                 WHERE clusterBlackListEventId = eventId
                       AND eventState = \"ToFIX\"
                       AND clusterBlackListClusterName = \"#{@name}\"
                       AND (clusterBlackListMJobsID = #{mjobid}
                            OR clusterBlackListMJobsID = 0)
            "
    sql_events=@dbh.select_all(query)
    if sql_events[0]['count']
      return false
    else
      return true
    end
  end
end

