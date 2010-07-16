
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
    if sql_events[0]['count'] == "0"
      return true
    else
      return false
    end
  end

  # get relative free resources(based on free nodes and flood rate)
  def free_resources
	if get_conf("FLOOD_RATE")
            flood_rate=get_conf("FLOOD_RATE")
    else
            flood_rate = 0
    end

	query = "SELECT sum(nodeMaxWeight) 
             FROM nodes
             WHERE nodeClusterName=\"#{@name}\" "

	sql_result=@dbh.select_all(query)
	max_weight=sql_result[0][0];


	query = "SELECT sum(nodeFreeWeight) 
			 FROM nodes
			 WHERE nodeClusterName=\"#{@name}\" "

	sql_result=@dbh.select_all(query)
	free_weight = sql_result[0][0];

	return free_weight.to_i + (flood_rate.to_f*max_weight.to_i)

  end

end


######################################################################### 
# Functions 
######################################################################### 
 
#return array of cigri clusters 
def get_cigri_clusters(dbh)
   query = "SELECT * from clusters"
   sql_clusters=dbh.select_all(query)
   clusters=[]
   sql_clusters.each do |sql_cluster|
      cluster=Cluster.new(dbh,sql_cluster['clusterName'])
      clusters << cluster
   end
   return clusters
end

