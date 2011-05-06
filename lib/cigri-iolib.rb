require 'cigri-conflib'
require 'cigri-exception'
require 'cigri-logger'
require 'dbi'

# Configuration for IOLIB
CONF = Cigri.conf
# logger to use in IOLIB
IOLIBLOGGER = Cigri::Logger.new('IOLIB', CONF.get('LOG_FILE'))

##
# Method to obtain a database handle from the information given in cigri.conf
# If a block is given, it will disconnect automatically at the end of execution
# == Usage:
# - dbh = db_connect()
#   ...
#   dbh.disconnect
# - db_connect() do |dbh|
#   ...
#   end
#
# == Returns:
# database handle
#
# == Yields
# database handle
#
# == Exceptions:
# - Cigri::Exceptions if config badly defined
# - DBI exceptions
##
def db_connect()
  str = "DBI:#{CONF.get('DATABASE_TYPE')}:#{CONF.get('DATABASE_NAME')}:#{CONF.get('DATABASE_HOST')}"
  dbh = DBI.connect(str, 
                    "#{CONF.get('DATABASE_USER_NAME')}", 
                    "#{CONF.get('DATABASE_USER_PASSWORD')}")
  return dbh unless block_given?
  yield dbh
  dbh.disconnect()
end


##
# Method defined to get the last inserted id in a database
# == Usage
#    db_connect() do |dbh|
#      dbh.do('INSERT ... INTO table')
#      ID = last_inserted_id(dbh, 'table_row_seq')
#    end
#
# == Parameters
# - dbh: databale handle
# - seqname: sequence name to retreive the last-id
#
# == Exceptions
# - Cigri::Exception if database type defined in cigri.conf not supported 
##
def last_inserted_id(dbh, seqname = '')
  db = CONF.get('DATABASE_TYPE')
  if db.eql? 'Pg'
    row = dbh.select_one("SELECT currval('#{seqname}')")
  elsif db.eql? 'Mysql'
    row = dbh.select_one("SELECT LAST_INSERT_ID()")
  else
    raise Cigri::Exception, "impossible to retreive last inserted id: database type \"#{db}\" is not supported"
  end
  return row[0]
end

##
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
##
def cigri_submit(dbh, json, user)
  IOLIBLOGGER.debug('Saving campaign into database')
  dbh['AutoCommit'] = false
  begin
    #INSERT INTO campaigns
    query = 'INSERT into campaigns 
             (grid_user, state, type, name, submission_time, jdl)
             VALUES (?, \'in_treatment\', ?, ?, NOW(),  ?)'
    dbh.do(query, user, json['jobs_type'], json['name'], json.to_json)
    
    campaign_id = last_inserted_id(dbh, 'campaigns_id_seq')
    
    #add campaigns properties
    query = 'INSERT INTO campaign_properties 
             (name, value, cluster_id, campaign_id)
             VALUES (?, ?, ?, ?)'
    at_least_one_cluster = false
    dbh.prepare("SELECT id FROM clusters where name = ?") do |sth|
      json['clusters'].each_key do |cluster|
        sth.execute(cluster)
        cluster_id = sth.first
        if cluster_id
          cluster_id = cluster_id[0]
          at_least_one_cluster = true
          dbh.do(query, '', '', cluster_id, campaign_id)
        else
          IOLIBLOGGER.warn("Cluster '#{cluster}' unknown, campaign_property not added for this cluster")
        end
      end
      raise Cigri::Exception, "No clusters usable for the campaign" unless at_least_one_cluster
    end
    
    #create bag_of_tasks
    unless json['jobs_type'].eql?('desktop_computing')
      query = 'INSERT INTO bag_of_tasks 
               (name, param, campaign_id)
               VALUES (?, ?, ?)'
      json['params'].each do |param|
        dbh.do(query, param.split.first, param, campaign_id)
      end
    else
      raise Cigri::Exception, 'Desktop_computing campaigns are not yet sopported'
    end
    
    dbh.commit()
  rescue Exception => e
    IOLIBLOGGER.error('Error running campaign submission: ' + e.inspect)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
end

##
# Returns the ID in the database of the cluster corresponding to the name
#
# == Parameters
# - dbh: database handle
# - cluster_name: name of the cluster that we need the name
#
# == Returns
# - ID of the cluster
# - nil if cluster not found
##
def get_cluster_id(dbh, cluster_name)
  row = dbh.select_one("SELECT id FROM clusters WHERE name = '#{cluster_name}'")
  return row[0] if row
  nil
end

##
# Returns the IDs in the database of the clusters corresponding to the names
#
# == Parameters
# - dbh: database handle
# - clusters_names: list of names
#
# == Returns
# - hash (name=>ID)
##
def get_clusters_ids(dbh, clusters_names)
  res = {}
  dbh.select_all("SELECT name, id FROM clusters WHERE name IN ('#{clusters_names.join('\',\'')}')"){|row| res[row['name']] = row['id']}
  res
end


##
# Insert a new cluster into the database
#
# == Parameters
# - dbh: database handle
# - all the fields of the clusters database
# 
#
# == Returns
# - false if failed
##
def new_cluster(dbh, name, api_url, api_username, api_password, ssh_host, batch, resource_unit, power, properties)
  IOLIBLOGGER.debug("Creating the new cluster #{name}")
  dbh['AutoCommit'] = false
  begin
    query = 'INSERT into clusters
             (name,api_url,api_username,api_password,ssh_host,batch,resource_unit,power,properties)
             VALUES (?,?,?,?,?,?,?,?,?)'
    dbh.do(query,name,api_url,api_username,api_password,ssh_host,batch,resource_unit,power,properties)
    dbh.commit()
  rescue Exception => e
    IOLIBLOGGER.error("Error inserting cluster #{name}: " + e.inspect)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
end

##
# Get cluster informations
# 
# == Parameters
# - dbh: database handle
# - id: id of the cluster
#
# == Returns
# - hash
##
def get_cluster(dbh,id)
  sth = dbh.execute("SELECT * FROM clusters WHERE id=#{id}")
  res=sth.fetch_hash
  if res.nil?
    IOLIBLOGGER.error("No cluster with id=#{id}!")
    raise Cigri::Exception, "No cluster with id=#{id}!"
  else
    res
  end
end

