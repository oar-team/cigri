require 'cigri-conflib'
require 'cigri-exception'
require 'cigri-logger'
require 'cigri-utils'
require 'json'

CONF = Cigri.conf
LOGGER = Cigri::Logger.new('IOLIB', CONF.get('LOG_FILE'))

# This method saves a new campaign into the cigri database.
# It considers that the JDL has been checked before submitting and is 
# therefore correct.
#
# == Parameters
# - dbh: database handle
# - json: expended json corresponding to JDL
# - user: username in the database
# 
# == Exceptions
# - Cigri::Exception: if no cluster used in the campaign are defined
# - Exception: Error with the database
#
def cigri_submit(dbh, json, user)
  LOGGER.debug('Saving campaign into database')
  dbh['AutoCommit'] = false
  begin
    #INSERT INTO campaigns
    query = 'INSERT into campaigns 
             (grid_user, state, type, name, submission_time, jdl)
             VALUES (?, \'in_treatment\', ?, ?, NOW(),  ?)'
    dbh.do(query, user, json['jobs_type'], json['name'], json.to_json)
    
    campaign_id = last_inserted_id(dbh, 'campaigns_id_seq')
    
    #add campaigns properties
    at_least_one_cluster = false
    sth = dbh.prepare("SELECT id FROM clusters where name = ?")
    json['clusters'].each_key do |cluster|
      sth.execute(cluster)
      cluster_id = sth.first
      if cluster_id
        cluster_id = cluster_id[0]
        at_least_one_cluster = true
        query = 'INSERT INTO campaign_properties 
                 (name, value, cluster_id, campaign_id)
                 VALUES (?, ?, ?, ?)'
        dbh.do(query, '', '', cluster_id, campaign_id)
      else
        LOGGER.warn("Cluster '#{cluster}' unknown, campaign_property not added for this cluster")
      end
    end
    raise Cigri::Exception, "No clusters usable for the campaign" unless at_least_one_cluster
    sth.finish()
    
    #create bag_of_tasks
    unless json['jobs_type'].eql?('desktop_computing')
      
    else
      raise Cigri::Exception, 'Desktop_computing campaigns are not yet sopported'
    end
    
    dbh.commit()
  rescue Exception => e
    LOGGER.error('Error running campaign submission: ' + e.inspect)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
end


#
# Returns the ID in the database of the cluster corresponding to the name
#
# == Parameters
# - dbh: database handle
# - cluster_name: name of the cluster that we need the name
#
# == Returns
# - ID of the cluster
# - nil if cluster not found
#
def get_cluster_id(dbh, cluster_name)
  row = dbh.select_one("SELECT id FROM clusters WHERE name = '#{cluster_name}'")
  return row[0] if row
  nil
end

#
# Returns the IDs in the database of the clusters corresponding to the names
#
# == Parameters
# - dbh: database handle
# - clusters_names: list of names
#
# == Returns
# - hash (name=>ID)
# - nil if clusters not found or if no clusters_names defined
#
def get_clusters_ids(dbh, clusters_names)
  return nil unless clusters_names.length > 0
  rows = dbh.select_all("SELECT name, id FROM clusters WHERE name IN ('#{clusters_names.join('\',\'')}')")
  return nil unless rows
  res = {}
  rows.each do |row|
    res[row['name']] = row['id']
  end
  res
end




