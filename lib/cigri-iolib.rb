require 'cigri-conflib'
require 'cigri-exception'
require 'cigri-logger'
$VERBOSE=false
require 'dbi'
$VERBOSE=true
require 'pp'
require 'json'

# Configuration for IOLIB
CONF = Cigri.conf unless defined? CONF
# logger to use in IOLIB
IOLIBLOGGER = Cigri::Logger.new('IOLIB', CONF.get('LOG_FILE'))

#######################################################################
######################### iolib functions #############################
#######################################################################

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
# - Cigri::Errors if config badly defined
# - DBI exceptions
##
def db_connect()
  begin
    str = "DBI:#{CONF.get('DATABASE_TYPE')}:#{CONF.get('DATABASE_NAME')}:#{CONF.get('DATABASE_HOST')}"
    $VERBOSE=false
    dbh = DBI.connect(str, 
                      "#{CONF.get('DATABASE_USER_NAME')}", 
                      "#{CONF.get('DATABASE_USER_PASSWORD')}")
    $VERBOSE=true
    return dbh unless block_given?
    yield dbh
    dbh.disconnect() if dbh
  rescue DBI::OperationalError => e
    IOLIBLOGGER.error("Failed to connect to database with string: #{str}\nError: #{e}\n#{e.backtrace.join("\n")}")
    IOLIBLOGGER.error("Retrying in 10s")
    GC.start
    sleep 10
    retry
  rescue Exception => e
    IOLIBLOGGER.error("Failed to connect to database with string: #{str}\nError: #{e}\n#{e.backtrace.join("\n")}")
    raise
  end
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
# - Cigri::Error if database type defined in cigri.conf not supported 
##
def last_inserted_id(dbh, seqname = '')
  db = CONF.get('DATABASE_TYPE')
  if db.eql? 'Pg'
    query = "SELECT currval(?)"
    row = dbh.select_one(query, seqname)
  else
    raise Cigri::Error, "Impossible to retreive last inserted id: database type \"#{db}\" is not supported"
  end
  row[0]
end

##
# Return the date from the SQL server
##
def db_date(dbh)
  query = "SELECT now()"
  row = dbh.select_one(query)
  row[0]
end

##
# Method defined to get available types for clusters APIs
#
# == Parameters
# - dbh: databale handle
#
# == Returns
# - Array of available types: ["oar2_5", "g5k"]
#
# == Exceptions
# - Cigri::Error if database type defined in cigri.conf not supported 
##
def get_available_api_types(dbh)
  db = CONF.get('DATABASE_TYPE')
  if db.eql? 'Pg'
    return dbh.select_all("select enumlabel from pg_enum where enumtypid = 'api'::regtype").flatten!
  else
    raise Cigri::Error, "Impossible to retreive available types: database type \"#{db}\" is not supported"
  end
  
end


##
# Quote escapes potentially dangerous caracters in SQL
#
# == Parameters
# - string: string to escape
#
# == Output
# - escaped string
##
def quote(value)
  return value if value.kind_of?(String) and value[0..8]=="TIMESTAMP"
  return value if value.kind_of?(String) and value[0..16]=="CURRENT_TIMESTAMP"
  return value if value.kind_of?(String) and value[0..4]=="now()"
  return "E'#{ value.gsub(/\\/){ '\\\\' }.gsub(/'/){ '\\\'' } }'" if value.kind_of?(String)
  "'#{value}'"
end

##
# Returns the SQL form of a unix timestamp (integer or Time object)
#
def to_sql_timestamp(timestamp)
  return "TIMESTAMP WITH TIME ZONE 'epoch' + #{timestamp.to_i} * INTERVAL '1 second'"
end

## 
# Execute the admission rules
#
# == Parameters
# - vars: variables scope (binding)
#
# == Exceptions
# If an admission rule fails, then exits with AdmissionRuleError
#
# == Output
# nil
def check_admission_rules(vars)
  rules=Dataset.new("admission_rules",:where => "true order by id")
  rules.each do |rule|
    begin 
      IOLIBLOGGER.debug("Running admission rule #{rule.props[:id]}")
      eval rule.props[:code], vars
    rescue => e
      raise Cigri::AdmissionRuleError, "rule #{rule.props[:id]} failed: #{e.message}"
    end
  end
  eval "jdl", vars
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
# - Cigri::Error: if no cluster used in the campaign are defined
# - Exception: Error with the database
#
# == Output
# - Campaign id
##
def cigri_submit(dbh, jdl, user)
  IOLIBLOGGER.debug('Saving campaign into database')
  dbh['AutoCommit'] = false
  begin
    params = jdl['params']
    jdl['params'] = []

    jdl=check_admission_rules(binding)

    #INSERT INTO campaigns
    query = 'INSERT into campaigns 
             (grid_user, state, type, name, submission_time, nb_jobs, jdl)
             VALUES (?, \'in_treatment\', ?, ?, NOW(), ?, ?)'
    dbh.do(query, user, jdl['jobs_type'], jdl['name'], 0, jdl.to_json)
    
    campaign_id = last_inserted_id(dbh, 'campaigns_id_seq')
    clusters = get_clusters_ids(dbh, jdl['clusters'].keys)
    
    #add campaigns properties
    query = 'INSERT INTO campaign_properties 
             (name, value, cluster_id, campaign_id)
             VALUES (?, ?, ?, ?)'
    at_least_one_cluster = false
    jdl['clusters'].each_key do |cluster|
      cluster_id = clusters[cluster]
      if cluster_id
        at_least_one_cluster = true
        %w{checkpointing_type dimensional_grouping epilogue exec_file 
          output_destination output_file output_gathering_method prologue 
          properties resources temporal_grouping walltime type test_mode max_jobs 
          prologue_walltime epilogue_walltime project exec_directory}.each do |prop|
            if jdl['clusters'][cluster][prop]
              if prop == "prologue" || prop == "epilogue"
                jdl['clusters'][cluster][prop]=jdl['clusters'][cluster][prop].join("\n")
              end
              dbh.do(query, prop, jdl['clusters'][cluster][prop], cluster_id, campaign_id)
            end
        end
      else
        IOLIBLOGGER.warn("Cluster '#{cluster}' unknown, campaign_property not added for this cluster")
      end
    end
    raise Cigri::Error, "No clusters usable for the campaign" unless at_least_one_cluster

    # Create bag_of_tasks
    unless jdl['jobs_type'].eql?('desktop_computing')
      cigri_submit_jobs(dbh, params, campaign_id, user)
    else
      raise Cigri::Error, 'Desktop_computing campaigns are not yet supported'
    end
    
    dbh.commit()
  rescue Exception => e
    IOLIBLOGGER.error('Error running campaign submission: ' + e.inspect + e.backtrace.to_s)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
  campaign_id
end

##
# This method adds more tasks to an already existing campaign.
# It considers that authentication has been done, so that the user adding the 
# campaigns is authorized to do so.
#
# == Parameters
# - dbh: database handle
# - params: an array or parameters: ["param 1 a b c", "param2 a b c"]
# - campaign_id: campaign in which to add the params 
#
##
def cigri_submit_jobs(dbh, params, campaign_id, user)
  IOLIBLOGGER.debug("Adding new tasks to campaign #{campaign_id}")

  check_rights!(dbh, user, campaign_id)

  campaign = dbh.select_one("SELECT state, jdl FROM campaigns WHERE id = ?", campaign_id)
  raise Cigri::Error, "Unable to add jobs to campaign #{campaign_id} because it was cancelled" if campaign[0] == "cancelled"

  jdl = JSON.parse(campaign[1])
  jdl['params'].concat(params)

  old_autocommit = dbh['AutoCommit']
  dbh['AutoCommit'] = false
  begin

    dbh.do("UPDATE campaigns SET state = 'in_treatment' WHERE id = ?", campaign_id) if campaign[0] == "terminated"
    dbh.do("UPDATE campaigns SET jdl = ?, nb_jobs = ? WHERE id = ?", jdl.to_json, jdl['params'].length, campaign_id)

    base_query = 'INSERT INTO parameters
                  (name, param, campaign_id)
                  VALUES '
    #TODO configure size of loop (10000 should be in conf file)
    while params.length > 0 do
      slice = params.slice!(0...10000)
      slice.map!{ |param| "(#{quote(param.to_s.split.first)}, #{quote(param)}, #{campaign_id})"}

      sth = dbh.execute(base_query + slice.join(', ') + " RETURNING id")
      inserted_ids = sth.fetch_all
      sth.finish

      inserted_ids.map!{ |param| "(#{param[0]}, #{campaign_id}, 10)"}
      dbh.do('INSERT INTO bag_of_tasks (param_id, campaign_id, priority) VALUES ' + inserted_ids.join(','))
    end
    dbh.commit() unless old_autocommit == false
  rescue Exception => e
    IOLIBLOGGER.error("Error adding new jobs to campaign #{campaign_id}: " + e.inspect)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = old_autocommit
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
  query = "SELECT id FROM clusters WHERE name = ? and enabled=true"
  row = dbh.select_one(query, cluster_name)
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
  if clusters_names.length > 0
    query = 'SELECT name, id FROM clusters WHERE name IN (?' << ',?' * (clusters_names.length - 1) << ')'
    dbh.select_all(query, *clusters_names){|row| res[row['name']] = row['id']}
  end
  res
end

##
# Insert a new cluster into the database
#
# == Parameters
# - dbh: database handle
# - all the fields of the clusters database
#
# == Exceptions
# - Exception if insertion failed
##
def new_cluster(dbh, name, api_url, api_auth_type, api_username, api_password, api_auth_header, ssh_host, batch, resource_unit, power, properties)
  IOLIBLOGGER.debug("Creating the new cluster #{name}")
  begin
    query = 'INSERT into clusters
             (name,api_url,api_auth_type,api_username,api_password,api_auth_header,ssh_host,batch,resource_unit,power,properties)
             VALUES (?,?,?,?,?,?,?,?,?,?, ?)'
    dbh.do(query,name,api_url,api_auth_type,api_username,api_password,api_auth_header,ssh_host,batch,resource_unit,power,properties)
  rescue Exception => e
    IOLIBLOGGER.error("Error inserting cluster #{name}: " + e.inspect)
    raise e
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
def get_cluster(dbh, id)
  query = "SELECT * FROM clusters WHERE id = ?"
  sth = dbh.execute(query, id)
  res = sth.fetch_hash
  sth.finish
  if res.nil?
    IOLIBLOGGER.error("No cluster with id=#{id}!")
    raise Cigri::NotFound, "No cluster with id=#{id}!"
  end
  res
end

##
# Select clusters
# 
# == Parameters
# - dbh: database handle
# - where_clause: the part after the where of an sql query into the cluster table
#
# == Returns
# - array of cluster ids
##
def select_clusters(dbh, where_clause = nil)
  if where_clause.nil?
    where_clause = "WHERE enabled=true"
  else
    where_clause = "WHERE #{where_clause} and enabled=true"
  end 
  dbh.select_all("SELECT id FROM clusters #{where_clause}").flatten!
end

##
# Cancels a campaign and all the data linked to it in the database
#
# == Parameters
# - dbh: database handle
# - user: user requesting campaign deletion
# - id: campaign id to cancel
#
# == Returns
# - 1 if campaign was cancelled successfully
# - 0 if the campaign was already cancelled
#
# == Exceptions
# - Cigri::Unauthorized if the user does not have the rights to cancel the campaign
# - Cigri::NotFound if the campaign "id" does not exist
#
##
def cancel_campaign(dbh, user, id)
  IOLIBLOGGER.debug("Received request to cancel campaign '#{id}'")
  
  check_rights!(dbh, user, id)

  nb = 0
  dbh['AutoCommit'] = false
  begin
    query = "DELETE FROM jobs_to_launch WHERE task_id in (SELECT id from bag_of_tasks where campaign_id = ?)"
    nb = dbh.do(query, id)
    IOLIBLOGGER.debug("Deleted #{nb} 'jobs_to_launch' for campaign #{id}")
    
    to_delete = {'bag_of_tasks' => 'campaign_id'} 
    to_delete.each do |k, v|
      nb = dbh.do("DELETE FROM #{k} WHERE #{v} = ?", id)
      IOLIBLOGGER.debug("Deleted #{nb} rows from table '#{k}' for campaign #{id}")
    end 
       
    #query = "UPDATE jobs SET state = 'event' WHERE campaign_id = ? AND state != 'terminated'"
    #nb = dbh.do(query, id)

    query = "UPDATE campaigns SET state = 'cancelled' where id = ? and state != 'cancelled'"
    nb = dbh.do(query, id)
    
    dbh.commit()
  rescue Exception => e
    IOLIBLOGGER.error('Error during campaign deletion, rolling back changes: ' + e.inspect)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
  IOLIBLOGGER.info("Campaign #{id} cancelled")
  nb
end

##
# Holds (pauses) a campaign
#
# == Parameters
# - dbh: database handle
# - user: user requesting campaign holding
# - id: campaign id to cancel
#
# == Exceptions
# - Cigri::Unauthorized if the user does not have the rights to cancel the campaign
# - Cigri::NotFound if the campaign "id" does not exist
#
##
def hold_campaign(dbh, user, id)
  IOLIBLOGGER.debug("Received request to pause campaign '#{id}'")
  
  check_rights!(dbh, user, id)

  begin
    query = "UPDATE campaigns SET state='paused' WHERE id=? and state='in_treatment'"
    dbh.do(query, id)
  rescue Exception => e
    IOLIBLOGGER.error('Error during campaign holding' + e.inspect)
    raise e
  end
  IOLIBLOGGER.info("Campaign #{id} paused")
end

##
# Resumes a holded campaign
#
# == Parameters
# - dbh: database handle
# - user: user requesting campaign resuming
# - id: campaign id to resume
#
# == Exceptions
# - Cigri::Unauthorized if the user does not have the rights to cancel the campaign
# - Cigri::NotFound if the campaign "id" does not exist
#
##
def resume_campaign(dbh, user, id)
  IOLIBLOGGER.debug("Received request to resume campaign '#{id}'")
  
  check_rights!(dbh, user, id)

  begin
    query = "UPDATE campaigns SET state='in_treatment' WHERE id=? and state='paused'"
    dbh.do(query, id)
  rescue Exception => e
    IOLIBLOGGER.error('Error during campaign resuming' + e.inspect)
    raise e
  end
  IOLIBLOGGER.info("Campaign #{id} resumed")
end

##
# Deletes a campaign and all the data linked to it in the database
#
# == Parameters
# - dbh: database handle
# - user: user requesting campaign deletion
# - id: campaign id to delete
#
# == Exceptions
# - Cigri::Unauthorized if the user does not have the rights to delete the campaign
# - Cigri::NotFound if the campaign "id" does not exist
#
##
def delete_campaign(dbh, user, id)
  IOLIBLOGGER.debug("Received request to delete campaign '#{id}'")
  
  check_rights!(dbh, user, id)
  
  dbh['AutoCommit'] = false
  begin
    nb = dbh.do("DELETE FROM jobs_to_launch WHERE task_id in (SELECT id from bag_of_tasks where campaign_id = ?)", id)
    IOLIBLOGGER.debug("Deleted #{nb} 'jobs_to_launch' for campaign #{id}")

    to_delete = {'campaigns' => 'id', 'bag_of_tasks' => 'campaign_id',
                 'campaign_properties' => 'campaign_id', 'jobs' =>'campaign_id',
                 'parameters' => 'campaign_id', 'events' => 'campaign_id'} 
    
    to_delete.each do |k, v|
      nb = dbh.do("DELETE FROM #{k} WHERE #{v} = ?", id)
      IOLIBLOGGER.debug("Deleted #{nb} rows from table '#{k}' for campaign #{id}")
    end 
    
    dbh.commit()
    IOLIBLOGGER.info("Campaign #{id} deleted")
  rescue Exception => e
    IOLIBLOGGER.error('Error during campaign deletion, rolling back changes: ' + e.inspect)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
end

##
# Purge a campaign: deletes parameters if campaign is finished
# to free up disk usage. All other logs are kepts.
#
# == Parameters
# - dbh: database handle
# - user: user requesting campaign deletion
# - id: campaign id to purge
#
# == Exceptions
# - Cigri::Unauthorized if the user does not have the rights to delete the campaign
# - Cigri::NotFound if the campaign "id" does not exist
#
##
def purge_campaign(dbh, user, id)
  IOLIBLOGGER.debug("Received request to purge campaign '#{id}'")
  
  check_rights!(dbh, user, id)
  
  dbh['AutoCommit'] = false
  begin

    row = dbh.select_one("SELECT state FROM campaigns WHERE id = ?", id)
    if row[0] != "cancelled" and row[0] != "terminated"
      IOLIBLOGGER.warn("Not purging non-terminated campaign #{id}")
      return false
    end

    to_delete = {'parameters' => 'campaign_id','bag_of_tasks' => 'campaign_id'} 
    
    to_delete.each do |k, v|
      nb = dbh.do("DELETE FROM #{k} WHERE #{v} = ?", id)
      IOLIBLOGGER.debug("Deleted #{nb} rows from table '#{k}' for campaign #{id}")
    end 
    
    dbh.commit()
    IOLIBLOGGER.info("Campaign #{id} purge")
  rescue Exception => e
    IOLIBLOGGER.error('Error during campaign purge, rolling back changes: ' + e.inspect)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
end



##
# Closes all the events opened on a campaign
#
# == Parameters
# - dbh: database handle
# - user: user requesting campaign events fixing 
# - id: campaign id to fix
#
# == Exceptions
# - Cigri::Unauthorized if the user does not have the rights to delete the campaign
# - Cigri::NotFound if the campaign "id" does not exist
#
##
def close_campaign_events(dbh, user, id)
  IOLIBLOGGER.debug("Received request to close all events for campaign '#{id}'")
  check_rights!(dbh, user, id)
  nb = dbh.do("UPDATE events 
                SET state='closed' 
                WHERE campaign_id = ? AND NOT code = 'BLACKLIST'", id)
  IOLIBLOGGER.debug("Closed #{nb} 'events' for campaign #{id}")
end

##
# Closes an event
#
# == Parameters
# - dbh: database handle
# - user: user requesting campaign event fixing 
# - id: event id to fix
#
# == Exceptions
# - Cigri::Unauthorized if the user does not have the rights to delete the event
# - Cigri::NotFound if the event "id" does not exist
#
##
def close_event(dbh, user, id)
  IOLIBLOGGER.debug("Received request to close the event '#{id}'")
  event=Cigri::Event.new(:id=>id)
  raise Cigri::NotFound, "Event #{id} not found" unless event.props
  if event.props[:campaign_id].to_s=='' && user != 'root'
    raise Cigri::Unauthorized, "Not authorized to close event #{id}"
  end
  if user != 'root'
    check_rights!(dbh, user, event.props[:campaign_id])
  end
  dbh.do("UPDATE events 
                SET state='closed' 
                WHERE id = ?", id)
  IOLIBLOGGER.debug("Closed event ##{id}")
  event
end

##
# Updates a campaign 
#
# == Parameters
# - dbh: database handle
# - user: user requesting campaign deletion
# - id: campaign id to delete
# - hash: parameters to update
#
# == Exceptions
# - Cigri::Unauthorized if the user does not have the rights to delete the campaign
# - Cigri::NotFound if the campaign "id" does not exist
#
##
#TODO spec !!!!
def update_campaign(dbh, user, id, hash)
  IOLIBLOGGER.debug("Received request to update campaign '#{id}'")
  
  check_rights!(dbh, user, id)
  
  if hash.size > 0
    query = 'UPDATE campaigns SET '
    sep = false
    hash.each do |k, v|
      query << ', ' if sep
      sep = true
      query << "#{k} = #{quote(v)} "
      IOLIBLOGGER.debug("Updating #{k} = #{quote(v)} for campaign #{id}")
    end
    query << "WHERE id = ?"
    begin 
      dbh.do(query, id)
      IOLIBLOGGER.info("Campaign #{id} updated")
    rescue Exception => e
      IOLIBLOGGER.error('Error during campaign update: ' + e.inspect)
      raise e
    end
  end
end

##
# Check that the campaign exists and that the user is the right owner
#
# == Parameters
# - dbh: database handle
# - user: user requesting campaign deletion
# - id: campaign id to check
#
# == Exceptions
# - Cigri::Unauthaurized if the user does not have the rights to act on the campaign
# - Cigri::NotFound if the campaign "id" does not exist
#
##
def check_rights!(dbh, user, id)
  row = dbh.select_one("SELECT grid_user FROM campaigns WHERE id = ?", id)
  if not row
    IOLIBLOGGER.warn("Asked to check rights on a campaign that does not exist (#{id})")
    raise Cigri::NotFound, "Campaign #{id} not found"
  elsif row[0] != user && user != "root"
    IOLIBLOGGER.warn("User #{user} asked to modify campaign '#{id}' belonging to #{row[0]}.")
    raise Cigri::Unauthorized, "User '#{user}' is not the owner of campaign '#{id}'"
  end
end

##
# Returns an array of the campaigns currently running (state = in_treatment)
#
# == Parameters
# - dbh: dababase handle
#
# == Returns
# Array of campaigns
#
##
def get_running_campaigns(dbh)
  dbh.select_all("SELECT id FROM campaigns WHERE state = 'in_treatment'")
end

##
# Returns the properties of a given campaign
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
#
# == Returns
# Array of properties
#
##
def get_campaign_properties(dbh, id)
  result=[]
  sth = dbh.execute("SELECT name,value,cluster_id,campaign_id FROM campaign_properties WHERE campaign_id = ?", id)
  sth.fetch_hash do |row|
    result << row
  end
  sth.finish
  return result
end

##
# Returns the tasks of a campaign
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
# - limit
# - offset
#
# == Returns
# Array: [id, name, param, state]
#
##
def get_campaign_tasks(dbh, id, limit, offset)
  query = "SELECT p.id as id, p.name as name, p.param as param, j.state as state, j.cluster_id as cluster_id, j.id as cigri_job_id, j.remote_id as remote_id, l.cluster_id as queued_cluster
           FROM parameters as p
           LEFT JOIN jobs as j 
            ON p.id = j.param_id
           LEFT JOIN jobs_to_launch as l
            ON l.task_id=p.id
           WHERE p.campaign_id = ? 
           ORDER BY id
           LIMIT ? 
           OFFSET ?"

  dbh.select_all(query, id, limit, offset)
end

##
# Returns a task of a campaign
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
# - task_id
#
# == Returns
# Array: [id, name, param, state]
#
##
def get_campaign_task(dbh, id, task_id)
  query = "SELECT p.id, p.name, p.param, j.state
           FROM parameters as p
           LEFT JOIN jobs as j 
            ON p.id = j.param_id
           WHERE p.campaign_id = ?
             AND p.id = ?"

  task = dbh.select_one(query, id, task_id)
  if task
    query = "SELECT jobs.*, clusters.name as clustername
             FROM jobs, clusters
             WHERE param_id = ?
               AND jobs.cluster_id = clusters.id"
    task << dbh.select_all(query, task_id)
  end

  task
end

##
# Returns the open events of a campaign
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
# - limit
# - offset
#
# == Returns
# Array: [id,class,code,job_id,cluster_id,message,date_open]
#
##
def get_campaign_events(dbh, id, limit, offset, all = 0)
  # Wether we show open events for the current campaing AND open global events on the campaign's clusters
  # or we show open/closed events of the given campaign
  if all == 0
     state="state='open' and"
     global="or ( cluster_id in
                  (select distinct cluster_id from campaign_properties where campaign_id = #{id})
                  and campaign_id is null
                 )"
     filter=""
  else
     state=""
     global=""
     # Hidden events (only useful for cigri internals)
     filter="and code != 'REMOTE_WAITING_FRAG' and code != 'FRAG_RESUBMIT_BY_NIKITA'"
  end
  query = "SELECT id,class,code,job_id,cluster_id,message,date_open,parent,state
           FROM events
           WHERE #{state}
                 ( campaign_id = ? #{global} #{filter})
           ORDER BY id
           LIMIT ? 
           OFFSET ?"

  dbh.select_all(query, id, limit, offset)
end

##
# Returns the open events not specific to a campaign
#
# == Parameters
# - dbh: dababase handle
# - limit
# - offset
#
# == Returns
# Array: [id,class,code,job_id,cluster_id,message,date_open]
#
##
def get_global_events(dbh, limit, offset)
  query = "SELECT id,class,code,job_id,cluster_id,message,date_open,parent,state
           FROM events
           WHERE state='open' and class not in ('job','campaign')
           ORDER BY id
           LIMIT ? 
           OFFSET ?"

  dbh.select_all(query, limit, offset)
end

##
# Returns the number of open events of a campaign
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
#
# == Returns
# Integer
#
##
def get_campaign_nb_events(dbh, id)
  dbh.select_one("SELECT count(*)
                  FROM events
                  WHERE state='open'
                   AND ( campaign_id = ?
                      or (
                        cluster_id in
                          (select distinct cluster_id from campaign_properties where campaign_id = ?)
                        and campaign_id is null
                         )
                    )
                  ", id, id)[0]
end

##
# Returns the number of remaining tasks for a given campaign
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
#
# == Returns
# Number of tasks (integer)
#
##
def get_campaign_remaining_tasks_number(dbh, id)
  dbh.select_one("SELECT COUNT(*) FROM bag_of_tasks 
                                  LEFT JOIN jobs_to_launch ON bag_of_tasks.id = task_id
                                  WHERE task_id is null 
                                    AND campaign_id=?", id)[0]
end

##
# Returns the number of active jobs (running, waiting, event open, remotewaiting) for a given campaign
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
#
# == Returns
# Number of tasks (integer)
#
##
def get_campaign_active_jobs_number(dbh, id)
  dbh.select_one("SELECT COUNT(*) FROM (
                                         SELECT jobs.id FROM jobs,events
                                             WHERE jobs.id=events.job_id
                                                AND jobs.state='event'
                                                AND events.state='open'
                                                AND jobs.campaign_id=?
                                         UNION
                                         SELECT jobs.id FROM jobs 
                                             WHERE campaign_id=?
                                                 AND jobs.state IN ('running','submitted','to_launch','remote_waiting')
                                       ) AS current_jobs;",id,id)[0]
end

##
# Returns the number of active jobs (running, waiting, event open, remotewaiting) for a given campaign on a given cluster
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
# - cluster_id: cluster id
#
# == Returns
# Number of tasks (integer)
#
##
def get_campaign_active_jobs_number_on_cluster(dbh, id, cluster_id)
  dbh.select_one("SELECT COUNT(*) FROM jobs
                                  WHERE (jobs.state='running'
                                     OR jobs.state='submitted'
                                     OR jobs.state='to_launch'
                                     OR jobs.state='remote_waiting')
                                    AND jobs.cluster_id=?
                                    AND jobs.campaign_id=?", cluster_id, id)[0]
end


##
# Returns the number of queued jobs  for a given campaign on a given cluster
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
# - cluster_id: cluster id
#
# == Returns
# Number of tasks (integer)
#
##
def get_campaign_queued_jobs_number_on_cluster(dbh, id, cluster_id)
  dbh.select_one("SELECT COUNT(*) FROM jobs_to_launch, bag_of_tasks
                  WHERE jobs_to_launch.task_id = bag_of_tasks.id
                    AND jobs_to_launch.cluster_id = ?
                    AND bag_of_tasks.campaign_id = ?", cluster_id, id)[0]
end

##
# Returns the number of to_launch jobs for a given campaign
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
#
# == Returns
# Number of tasks (integer)
#
##
def get_campaign_to_launch_jobs_number(dbh, id)
  dbh.select_one("SELECT COUNT(*) FROM jobs_to_launch,bag_of_tasks
                                  WHERE task_id=bag_of_tasks.id
                                    AND campaign_id=?", id)[0]
end

##
# Returns the number of launching jobs for a given campaign
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
#
# == Returns
# Number of tasks (integer)
#
##
def get_campaign_launching_jobs_number(dbh, id)
  dbh.select_one("SELECT COUNT(*) FROM jobs
                                  WHERE state='launching'
                                    AND campaign_id=?", id)[0]
end

##
# Returns the number of completed tasks for a given campaign
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
#
# == Returns
# Number of tasks (integer)
#
##
def get_campaign_nb_finished_jobs(dbh, id)
dbh.select_one("SELECT COUNT(*) FROM jobs
                                WHERE campaign_id = ?
                                  AND param_id > 0 
                                  AND state = 'terminated'", id)[0]
end

##
# Returns the number of launching jobs for a given cluster
#
# == Parameters
# - dbh: dababase handle
# - id: cluster_id
#
# == Returns
# Number of jobs (integer)
#
##
def get_cluster_nb_launching_jobs(dbh, id)
dbh.select_one("SELECT COUNT(*) FROM jobs
                                WHERE cluster_id = ? 
                                  AND state = 'launching'", id)[0]
end

##
# Returns a hash with a campaign id as key and it's number of finished jobs as value
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
#
# == Returns
# Hash : {1=>14, 2=> 0}: campaign 1 has 14 jobs completed, campaign 2 has none
#
##
def get_campaigns_nb_finished_jobs(dbh, ids)
  result = Hash.new(0)
  return result if ids.length < 1

  dbh.execute("SELECT campaign_id, COUNT(*) 
              FROM jobs
              WHERE campaign_id in ('" << ids.join('\',\'') << "') 
                AND state = 'terminated' AND tag != 'prologue' AND tag != 'epilogue'
              GROUP BY campaign_id").each do |row|
    result[row[0]] = row[1]
  end

  result
end

##
# Returns ids of all the tasks of campaign "id"
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
# - number: number of tasks to return (infinite if nil)
#
# == Returns
# Array of ids
#
##
def get_tasks_ids_for_campaign(dbh, id, number = nil)
  limit = number ? "LIMIT #{number}" : ""
  dbh.select_all("SELECT bag_of_tasks.id FROM bag_of_tasks 
                         LEFT JOIN jobs_to_launch ON bag_of_tasks.id = task_id
                         WHERE task_id is null AND campaign_id=?
                         ORDER by bag_of_tasks.priority DESC,bag_of_tasks.id
                         #{limit}", id).flatten!
end

##
# Returns ids of tasks for a given campaign ordered for a given cluster 
# (using tasks_affinity table for sorting)
# Takes care of not giving tasks that have already been scheduled (ie
# already into the jobs_to_launch table)
#
# == Parameters
# - dbh: dababase handle
# - id: campaign id
# - max: number of tasks to return (infinite if nil)
#
# == Returns
# Array of ids
#
##
def get_tasks_ids_for_campaign_on_cluster(dbh, campaign_id, cluster_id, max = nil)
  return [] if max <= 0
  limit = max ? "LIMIT #{max}" : ""
  res=dbh.select_all("SELECT bag_of_tasks.id,
                         COALESCE(tasks_affinity.priority,0) as p 
                  FROM bag_of_tasks 
                  LEFT JOIN tasks_affinity 
                            ON bag_of_tasks.param_id = tasks_affinity.param_id and tasks_affinity.cluster_id=#{cluster_id} 
                  LEFT JOIN jobs_to_launch
                            ON bag_of_tasks.id = jobs_to_launch.task_id
                  WHERE bag_of_tasks.campaign_id=#{campaign_id} 
                        AND jobs_to_launch.task_id is null
                  ORDER by bag_of_tasks.priority desc,p desc,id
                  #{limit}")
   res.collect! {|a| a[0]}
   return res.flatten
end

##
# Get a new batch id
#
# == Parameters
# - dbh: database handle
##
def new_batch_id(dbh)
  query = "SELECT batch_id FROM jobs ORDER BY batch_id LIMIT 1"
  row = dbh.select_one(query)
  return row[0]+1 if row and not row[0].nil?
  return 1
end

##
# Insert jobs into the queue of a given cluster (jobs_to_launch table)
# 
# == Parameters
# - dbh: database handle
# - tasks: array of task ids to launch
# - cluster_id: cluster to launch tasks on
# - tag: tag (like prologue or epilogue)
# - runner_options: options for the runner (a ruby hash that will be 
#   converted into json for database storage). If grouping is requested
#   all the given tasks are grouped into a unique batch_id
##
def add_jobs_to_launch(dbh, tasks, cluster_id, tag, runner_options, order_num)
  if defined?(runner_options["temporal_grouping"]) or defined?(runner_options["dimensional_grouping"]) 
    runner_options["batch_id"]=new_batch_id(dbh)
  end
  runner_options=JSON.generate(runner_options)
  dbh['AutoCommit'] = false
  begin
    query = 'INSERT into jobs_to_launch
             (task_id,cluster_id,tag,runner_options,queuing_date,order_num)
             VALUES (?,?,?,?,now(),?)'
    tasks.each do |task_id|
      dbh.do(query, task_id, cluster_id, tag, runner_options, order_num)
    end
    dbh.commit()
  rescue Exception => e
    IOLIBLOGGER.error("Error inserting tasks into jobs_to_launch: " + e.inspect)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
end

##
# Take tasks from the bag of tasks and create new jobs into the jobs table
# 
# == Parameters
# - dbh: db handler
# - tasks: array of task id
#
# == Returns
# Array of job ids
##
def take_tasks(dbh, tasks)
  dbh['AutoCommit'] = false
  begin
    jobids = []
    counts = {}
    # Get the jobs from the cluster queue
    jobs = dbh.select_all("SELECT b.id as id, b.param_id as param_id, b.campaign_id as campaign_id, cluster_id, j.tag as tag, j.runner_options as runner_options 
                           FROM bag_of_tasks AS b, jobs_to_launch AS j
                           WHERE j.task_id = b.id AND
                                 b.id IN (#{tasks.join(',')})
                           ORDER BY b.priority DESC, b.id")
    jobs.each do |job|
      # delete from the bag of task
      dbh.do("DELETE FROM bag_of_tasks where id = #{job['id']}")     
      # delete from the cluster queue
      dbh.do("DELETE FROM jobs_to_launch where task_id = #{job['id']}")
      # Increment the count for (campaign,cluster) pair
      count_key=[job['campaign_id'], job['cluster_id']]
      counts[count_key] ? counts[count_key] += 1 : counts[count_key]=1
      # Get the batch_id if any
      batch_id="null"
      runner_options=JSON.parse(job['runner_options'])
      if defined?(runner_options["batch_id"])
        batch_id=runner_options["batch_id"].to_i
      end
      # insert the new job into the jobs table
      res=dbh.select_one("INSERT INTO jobs (campaign_id, state, cluster_id, param_id, tag, runner_options, batch_id)
              VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id",
              job['campaign_id'], "to_launch", job['cluster_id'], job['param_id'], job['tag'], 
                job['runner_options'], batch_id
            )
      jobids << res[0]
      IOLIBLOGGER.debug("Took task: #{res[0]}")
    end
    # Update the queue counts that are used for throughputs calculations
    counts.each do |pair,count|
      dbh.do("INSERT INTO queue_counts (date,campaign_id,cluster_id,jobs_count)
              VALUES (#{to_sql_timestamp(Time.now)}, ?, ?, ?)",
              pair[0],pair[1],count
            )
    end
    return jobids
  rescue Exception => e
    IOLIBLOGGER.error("Error taking tasks from the bag: " + e.inspect)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
end

##
# Remove remaining tasks for a given campaign: all the tasks
# left into the b-o-t and that are not scheduled are simply removed 
# from the b-o-t. This is used by the "test" mode.
# 
# == Parameters
# - dbh: db handler
# - campaign_id
#
##
def remove_remaining_tasks(dbh, campaign_id)
  dbh.do("DELETE FROM bag_of_tasks
           WHERE id IN 
            (SELECT bag_of_tasks.id FROM bag_of_tasks LEFT JOIN jobs_to_launch ON bag_of_tasks.id=task_id
              WHERE task_id IS NULL) 
            AND campaign_id = #{campaign_id}") 
end

##
# Add the null parameter if it is missing (done once at almighty boot)
#
def check_null_parameter(dbh)
 if dbh.select_one("SELECT COUNT(*) FROM parameters WHERE id = 0")[0] < 1
   IOLIBLOGGER.debug("Initializing the null parameter")
   dbh.do("INSERT INTO parameters (id,campaign_id,name,param)
                       VALUES (0,0,'null','null parameter for special jobs, dont delete!')")
 end
end

##
# Add a notification entry (subscription)
#
def add_notification_subscription(dbh,sub,user)
  user="%%admin%%" if user == "root"
  dbh.do("INSERT INTO user_notifications (grid_user,type,identity,severity)
                      VALUES (?,?,?,?)",
         user,sub['type'],sub['identity'],sub['severity'])
end

##
# Del a notification entry (unsubscription)
#
def del_notification_subscription(dbh,type,identity,user)
  user="%%admin%%" if user == "root"
  dbh.do("DELETE FROM user_notifications WHERE grid_user=? and type=? and identity=?",
         user,type,identity)
end
##
# Get the last inserted entry date from grid_usage table
#
def last_grid_usage_entry_date(dbh)
  result=dbh.select_one("SELECT extract(epoch from date) FROM grid_usage ORDER by date desc limit 1")
  return 0 if result.nil?
  result[0]
end

## 
# Get grid_usage infos between two dates (from and to)
# If from and to are not given, get the last timestamp
# and all corresponding entries
#
def get_grid_usage(dbh,from,to)
  query="select extract(epoch from date),cluster_id,max_resources,used_resources,used_by_cigri,unavailable_resources,clusters.name
            from grid_usage,clusters "
  if from.nil? and to.nil?
     last=last_grid_usage_entry_date(dbh)
     query+="where extract(epoch from date)=#{last} and clusters.id=grid_usage.cluster_id"
  elsif from.nil?
     query+="where extract(epoch from date)<=#{to} and clusters.id=grid_usage.cluster_id"
  elsif to.nil?
     query+="where extract(epoch from date)>#{from} and clusters.id=grid_usage.cluster_id"
  else
     query+="where extract(epoch from date)<=#{to} and extract(epoch from date)>#{from} and clusters.id=grid_usage.cluster_id"
  end
  dates={}
  result=dbh.select_all(query)
  result.each do |row|
    if dates[row[0]].nil?
      dates[row[0]] = []
    end
    dates[row[0]] << {
                        :cluster_name => row[6],
                        :cluster_id => row[1],
                        :max_resources => row[2],
                        :used_resources => row[3],
                        :used_by_cigri => row[4],
                        :unavailable_resources => row[5]
                      }
  end
  output=[]
  dates.each do |date,val|
    output << { :date => date.to_i, :clusters => val }
  end
  output
end

##
# Get average and stddev of the jobs duration of a campaign
#
def get_average_job_duration(dbh,campaign_id)
  query="select avg(extract(epoch from stop_time - start_time)),stddev(extract(epoch from stop_time - start_time)) from jobs where campaign_id=#{campaign_id} and stop_time is not null and start_time is not null and state='terminated'"
  res=dbh.select_all(query)
  return [0,0] if res.length == 0
  return res[0]
end

##
# Get jobs throughput of a campaign
#
def get_campaign_throughput(dbh,campaign_id,time_window)
  query="select max(extract(epoch from start_time)) from jobs where campaign_id=#{campaign_id} and state='terminated';"
  res=dbh.select_one(query)
  return 0 if res.nil?
  last_job_start=res[0].to_i
  query="select min(extract(epoch from start_time)) from jobs where extract(epoch from start_time) > #{last_job_start}-#{time_window} and campaign_id=#{campaign_id} and state='terminated';"
  res=dbh.select_one(query)
  return 0 if res.nil?
  first_job_start=res[0].to_i
  return 0 if (last_job_start - first_job_start) == 0
  query="select count(*) from jobs where extract(epoch from start_time) > #{last_job_start}-#{time_window} and campaign_id=#{campaign_id} and state='terminated';"
  res=dbh.select_one(query)
  return res[0].to_f/(last_job_start - first_job_start).to_f
end

##
# Get failures rate
#
def get_campaign_failures_rate(dbh,campaign_id)
  # count the jobs with events that are failures
  query="select count(*) from jobs,events where jobs.id=events.job_id and events.code != 'REMOTE_WAITING_FRAG' and jobs.campaign_id=#{campaign_id};"
  failures=dbh.select_one(query)[0].to_i
  # count the terminated jobs
  query="select count(*) from jobs where state='terminated' and jobs.campaign_id=#{campaign_id};"
  terminated=dbh.select_one(query)[0].to_i
  total=failures+terminated
  return 0 if total == 0
  return failures.to_f/total.to_f
end

##
# Get resubmit rate
#
def get_campaign_resubmit_rate(dbh,campaign_id)
  # count the jobs with events that are resubmits
  query="select count(*) from jobs,events where jobs.id=events.job_id and events.code = 'RESUBMIT' and jobs.campaign_id=#{campaign_id};"
  failures=dbh.select_one(query)[0].to_i
  # count the terminated jobs
  query="select count(*) from jobs where state='terminated' and jobs.campaign_id=#{campaign_id};"
  terminated=dbh.select_one(query)[0].to_i
  total=failures+terminated
  return 0 if total == 0
  return failures.to_f/total.to_f
end

##
# Decrease task affinity.
# If affinity is found, decrease by one. If not, initiate it to "-1".
# By default, we consider affinity to be "0".
#
def decrease_task_affinity(dbh,param_id,cluster_id)
  affinity=get_task_affinity(dbh,param_id,cluster_id)
  if affinity.nil?
    query="insert into tasks_affinity (param_id,cluster_id,priority)
           values (#{param_id},#{cluster_id},-1)"
  else
    priority=affinity[3].to_i
    id=affinity[0].to_i
    query="update tasks_affinity set priority=#{priority-1}
           where id=#{id}"
  end
  dbh.do(query)
end

##
# Get a specific affinity
#
def get_task_affinity(dbh,param_id,cluster_id)
  query="select id,param_id,cluster_id,priority from tasks_affinity 
         where param_id=#{param_id} and cluster_id=#{cluster_id}"
  dbh.select_one(query)
end
##
# Delete an affinity (ie reset it to 0)
#
def reset_task_affinity(dbh,param_id,cluster_id)
  query="delete from tasks_affinity where param_id=#{param_id} and cluster_id=#{cluster_id}"
  dbh.do(query)
end

##
# Clean tasks_affinity table
#
def clean_tasks_affinity_table(dbh)
  query="delete from tasks_affinity where id in (
           select tasks_affinity.id from tasks_affinity,parameters,campaigns 
              where tasks_affinity.param_id=parameters.id and parameters.campaign_id=campaigns.id 
                 and campaigns.state in ('terminated','cancelled'));"
  dbh.do(query)
end

##
# Reset cluster queues
#
def reset_cluster_queues(dbh)
  dbh['AutoCommit'] = false
  query="delete from jobs_to_launch"
  dbh.do(query)
  dbh.commit()
  dbh['AutoCommit'] = true 
end


#######################################################################
######################### iolib classes ###############################
#######################################################################

##
# Class for handling datarecords
# Shouldn't be used directly, but from Job, Campaign,...
# Examples:
#  - To insert a new job:
#  j=Cigri::Job.new(:campaign_id => 1, :state => "to_launch", :name => "obiwan1")
#  - To get a job from the id:
#  job=Cigri::Job.new(:id => 29)
#
##
class Datarecord
  attr_reader :props, :table

  # Creates a new record in the given table with the given 
  # properties (hash) or get the record if :id is given.
  def initialize(table,props={})
    @table=table
    # Set the name of the field used for index ("id" by default)
    if props[:index]
      @index=props[:index]
    else
      @index="id"
    end 
    # No id given, then create a new record
    if not props[:id]
      @props=props
      @props[:id]=new_record(table,props)
    # If an id is given, then get the object from the database
    # or simply initiate it from the props if props[:nodb] is true
    else
      if props[:nodb]
        @props=props
      else
        @props=get_record(table,props[:id],props[:what])
      end
    end
  end

  # Creates a new record and return its id
  def new_record(table,props={})
    db_connect() do |dbh|
      query = "INSERT into #{table} "
      what = []
      values = []
      props.each do |key, value|
        what << key
        values << quote(value)
      end    
      query << "(" + what.join(',') + ") VALUES (" + values.join(',') +")"
      dbh.do(query)
      return last_inserted_id(dbh, "#{table}_id_seq")
    end
  end

  # Get a new record and return its properties
  def get_record(table, id, what)
    dbh = db_connect()
    what = "*" if what.nil?
    sth = dbh.execute("SELECT #{what} FROM #{table} WHERE #{@index} = #{id.to_i}")
    # The inject part is to convert string keys into symbols to optimize memory
    record = sth.fetch_hash
    dbh.disconnect
    if record.nil?
      IOLIBLOGGER.warn("Datarecord #{@index}=#{id} not found into #{table}")
      return nil
    else      
      return record.inject({}){|h,(k,v)| h[k.to_sym] = v; h}
    end
  end
 
  # For fancy printing
  def to_s
    res="#{@table} record id #{@props[:id]}: \n"
    @props.each {|key, value| res+="  #{key}: #{value}\n" }
    return res
  end 

  # Delete the record from the database
  def delete
    db_connect() do |dbh|
      dbh.do("DELETE FROM #{@table} where #{@index}=#{props[:id]}")
    end
  end

  # Quick access to the id of the datarecord
  def id
    if @props.nil?
      return nil
    else
      return @props[:id].to_i
    end
  end

  # Update a datarecord into the database
  def update(values,table=@table)
    table=table.split(/,/)[0]
    db_connect() do |dbh|
      values.each do |field,value|
        # Special case of timestamps, should not be automatically quoted by the placeholder syntax
        if value.kind_of?(String) and value[0..8]=="TIMESTAMP"
          query = "UPDATE #{table} SET #{field} = #{value} WHERE #{@index} = ?"
          dbh.do(query, id)
        # Default case
        else
          query = "UPDATE #{table} SET #{field} = ? WHERE #{@index} = ?"
          dbh.do(query, value, id)
        end
      end
    end
  end

  # Same thing as update, but also update the object
  def update!(values,table=@table)
    update(values,table)
    values.each do |field,value|
      @props[field.to_sym]=value
    end
  end

  # Refresh (re-get from DB)
  def refresh!
    @props=get_record(@table,@props[:id],@props[:what])
  end

end

##
# Class for handling datasets
# A dataset is a set of datarecords
# Shouldn' be used directly, but from Jobset, Campaignset,...
# Example:
#  jobs=Cigri::Jobset.new(:where => "name like 'obiwan%'")
#
class Dataset
  attr_reader :records, :table
  @@dbh = nil
  @@counter = 0
  # Creates a new dataset
  # - If props[:values] is given, then insert the dataset into the given table
  # - If props[:where] is given, then get the dataset from the database
  # - The table value may be coma separated list of tables (for joins)
  def initialize(table,props={})
    # Get a DB handler
    @@dbh ||= db_connect()
    @dbh = @@dbh
    @table=table
    @records=[]
    if props[:where]
      fill(get(table,props[:what],props[:where]))
    elsif props[:values]
      fill(props[:values],false)
    end
  end

  # Fill the records array with the given values
  # values may be a Datarecord array, or an array of field=value
  def fill(values,nodb=true,table=@table)
    IOLIBLOGGER.debug("Making #{values.length} inserts into #{table}") unless nodb
    values.each do |record_props|
      record_props=record_props.props if record_props.is_a?(Datarecord)
      if nodb
        record_props[:nodb]=true 
      end
      @records << Datarecord.new(table,record_props)
    end
  end

  # Get a dataset from the database
  def get(table,what,where)
    what="*" if what.nil?
    check_connection!
    sth=@dbh.execute("SELECT #{what} FROM #{table} WHERE #{where}")
    result=[]
    sth.fetch_hash do |row|
      # The inject part is to convert string keys into symbols to optimize memory
      result << row.inject({}){|h,(k,v)| h[k.to_sym] = v; h}
    end
    return result
  end
  
  # Iterator
  def each(&blk)
    @records.each(&blk)
  end

  # Concatenation
  def +(dataset)
    dataset.records.each do |record|
      self << record
    end
    self
  end

  # Returns an array of all the ids of the datarecords of this dataset
  def ids
    @records.collect {|record| record.id}
  end

  # Return the number of data records
  def length
    @records.length
  end

  # Delete all the datarecords of this dataset from the database
  def delete(table=@table,id_column="id")
    IOLIBLOGGER.debug("Removing #{self.length} records from #{table}")    
    check_connection!
    @dbh.do("DELETE FROM #{table} WHERE #{id_column} in (#{self.ids.join(',')})")
  end
 
  # Same thing as delete, but also empty the dataset
  def delete!(table=@table)
    delete(table)
    @records=[]
  end

  # Update fields of the dataset into the database
  def update(values, table = @table, id_column = "id")
    table=table.split(/,/)[0]
    check_connection!
    values.each_key do |field|
      if values[field].kind_of?(String) and values[field][0..8]=="TIMESTAMP"
        # No quoting for timestamp function
        @dbh.do("UPDATE #{table} SET #{field} = #{values[field]} WHERE #{id_column} in (#{self.ids.join(',')})")
      else
        # Normal quoting
        @dbh.do("UPDATE #{table} SET #{field} = ? WHERE #{id_column} in (#{self.ids.join(',')})", values[field])
      end
    end
  end

  # Same thing as update, but also update the record objects
  def update!(values,table=@table,id_column="id")
    update(values,table,id_column)
    @records.each do |record|
      values.each do |field,value|
        record.props[field.to_sym]=value
      end
    end
  end

  # Add a Datarecord to the dataset
  def <<(record)
    @records << record
  end

  # Fancy print of the Dataset
  def to_s
    self.each do |data|
      puts data.to_s
    end
  end

  # Returns true if the Dataset is empty
  def empty?
    @records.empty?
  end

  private
  #Verify the state of the connection and connect if not
  def check_connection!
    if @@counter > 100 or !@@dbh.ping
      @@dbh = db_connect()
      @dbh = @@dbh
      @@counter = 0
    end
    @@counter += 1
  end
end
