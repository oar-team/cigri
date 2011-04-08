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
    json['clusters'].each do |cluster|
      sth.execute(cluster[0])
      cluster_id = sth.first
      if cluster_id
        cluster_id = cluster_id[0]
        at_least_one_cluster = true
        query = 'INSERT INTO campaign_properties 
                 (name, value, cluster_id, campaign_id)
                 VALUES (?, ?, ?, ?)'
        dbh.do(query, '', '', cluster_id, campaign_id)
      else
        LOGGER.warn("Cluster #{cluster[0]} unknown, campaign_property not added for this cluster")
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
