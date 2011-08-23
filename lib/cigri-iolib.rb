require 'cigri-conflib'
require 'cigri-exception'
require 'cigri-logger'
require 'dbi'
require 'pp'

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
# == Output
# - Campaign id
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
          %w{checkpointing_type dimensional_grouping epilogue exec_file 
            output_destination output_file output_gathering_method prologue 
            properties resources temporal_grouping walltime}.each do |prop|
            dbh.do(query, prop, json['clusters'][cluster][prop], cluster_id, campaign_id) if json['clusters'][cluster][prop]
          end
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
    return campaign_id
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
def select_clusters(dbh,where_clause)
  res=[]
  if where_clause.nil?
    where_clause=""
  else
    where_clause="WHERE #{where_clause}"
  end 
  dbh.select_all("SELECT id FROM clusters #{where_clause}"){|row| res.push(row["id"])}
  res
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
# - true if campaign was cancelled successfully
# - false if the user does not have the rights to cancel the campaign
# - nil if the campaign "id" does not exist
#
##
def cancel_campaign(dbh, user, id)
  IOLIBLOGGER.debug("Received request to cancel campaign '#{id}'")
  
  ok = check_rights(dbh, user, id)
  return ok unless ok
  
  dbh['AutoCommit'] = false
  begin
    #TODO add kill event in event table !!!!!
    nb = dbh.do("UPDATE jobs SET state = 'event' WHERE campaign_id = #{id} AND state != 'terminated'")
    IOLIBLOGGER.debug("Adding kill event for #{nb} jobs for campaign #{id}")
    
    nb = dbh.do("DELETE FROM jobs_to_launch WHERE task_id in (SELECT id from bag_of_tasks where campaign_id = #{id})")
    IOLIBLOGGER.debug("Deleted #{nb} 'jobs_to_launch' for campaign #{id}")
    
    nb = dbh.do("DELETE FROM bag_of_tasks WHERE campaign_id = #{id}")
    IOLIBLOGGER.debug("Deleted #{nb} rows from table 'bag_of_tasks' for campaign #{id}")
    
    nb = dbh.do("UPDATE campaigns SET state = 'cancelled' where id = #{id}")
    
    dbh.commit()
    IOLIBLOGGER.info("Campaign #{id} cancelled")
  rescue Exception => e
    IOLIBLOGGER.error('Error during campaign deletion, rolling back changes: ' + e.inspect)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
  true
end

##
# Deletes a campaign and all the data linked to it in the database
#
# == Parameters
# - dbh: database handle
# - user: user requesting campaign deletion
# - id: campaign id to delete
#
# == Returns
# - true if campaign was deleted successfully
# - false if the user does not have the rights to delete the campaign
# - nil if the campaign "id" does not exist
#
##
def delete_campaign(dbh, user, id)
  IOLIBLOGGER.debug("Received request to delete campaign '#{id}'")
  
  ok = check_rights(dbh, user, id)
  return ok unless ok
  
  dbh['AutoCommit'] = false
  begin
    to_delete = {'campaigns' => 'id', 'bag_of_tasks' => 'campaign_id',
                 'campaign_properties' => 'campaign_id', 'jobs' =>'campaign_id'} 
    
    nb = dbh.do("DELETE FROM jobs_to_launch WHERE task_id in (SELECT id from bag_of_tasks where campaign_id = #{id})")
    IOLIBLOGGER.debug("Deleted #{nb} 'jobs_to_launch' for campaign #{id}")
    
    to_delete.each do |k, v|
      nb = dbh.do("DELETE FROM #{k} WHERE #{v} = #{id}")
      IOLIBLOGGER.debug("Deleted #{nb} rows from table '#{k}' for campaign·#{id}")
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
  true
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
# == Returns
# - true if campaign was deleted successfully
# - false if the user does not have the rights to delete the campaign
# - nil if the campaign "id" does not exist
#
##
#TODO spec !!!!
def update_campaign(dbh, user, id, hash)
  IOLIBLOGGER.debug("Received request to update campaign '#{id}'")
  
  ok = check_rights(dbh, user, id)
  return ok unless ok
  
  if hash.size > 0
    query = 'UPDATE campaigns SET '
    sep = false
    hash.each do |k, v|
      query << ', ' if sep
      sep = true
      query << "#{k} = '#{v}' "
      IOLIBLOGGER.debug("Updating #{k} = '#{v}' for campaign #{id}")
    end
    query << "WHERE id = #{id}"
    begin 
      dbh.do(query)
      IOLIBLOGGER.info("Campaign #{id} updated")
    rescue Exception => e
      IOLIBLOGGER.error('Error during campaign update, rolling back changes: ' + e.inspect)
      raise e
    end
  end
  true
end

##
# Check that the campaign exists and that the user is the right owner
#
# == Parameters
# - dbh: database handle
# - user: user requesting campaign deletion
# - id: campaign id to check
#
# == Returns
# - true if campaign user is the owner of campaign id
# - false if the user does not have the rights to act on the campaign
# - nil if the campaign "id" does not exist
#
##
def check_rights(dbh, user, id)
  row = dbh.select_one("SELECT grid_user FROM campaigns WHERE id = #{id}")
  if not row
    IOLIBLOGGER.warn("Asked to check rights on a campaign that does not exist (#{id})")
    return nil
  elsif row[0] != user && user != "root"
    IOLIBLOGGER.warn("User #{user} asked to check rights for campaign '#{id}' belonging to #{row[0]}.")
    return false
  end
  true
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
#
# == Returns
# Array of campaigns
#
##
def get_campaign_properties(dbh,id)
  dbh.select_all("SELECT * FROM campaign_properties WHERE campaign_id = #{id}")
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
def get_campaign_remaining_tasks_number(dbh,id)
  row=dbh.select_one("SELECT COUNT(*) FROM bag_of_tasks 
                                  LEFT JOIN jobs_to_launch ON bag_of_tasks.id=task_id
                                  WHERE task_id is null AND campaign_id=#{id};")
  return row[0]
end

##
# Returns "number" tasks of campaign "id"
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
def get_tasks_for_campaign(dbh,id,number)
  tasks=[]
  if not number.nil?
    limit="LIMIT #{number}"
  else
    limit=""
  end
  dbh.select_all("SELECT bag_of_tasks.id FROM bag_of_tasks 
                            LEFT JOIN jobs_to_launch ON bag_of_tasks.id=task_id
                            WHERE task_id is null AND campaign_id=#{id}
                            ORDER by bag_of_tasks.id
                            #{limit};").each do |row|
    tasks << row["id"]
  end
  return tasks
end

##
# Insert jobs into the queue of a given cluster (jobs_to_launch table)
# 
# == Parameters
#
##
def add_jobs_to_launch(dbh,tasks,cluster_id,tag,runner_options)
  dbh['AutoCommit'] = false
  begin
    query = 'INSERT into jobs_to_launch
             (task_id,cluster_id,tag,runner_options)
             VALUES (?,?,?,?)'
    tasks.each do |task_id|
      dbh.do(query,task_id,cluster_id,tag,runner_options)
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
      query = "INSERT into #{table}\n"
      what=[]
      values=[]
      props.each do |key,value|
        what << key
        values << "'#{value}'"
      end    
      query += "(" + what.join(',') + ") VALUES (" + values.join(',') +")"
      dbh.do(query)
      return last_inserted_id(dbh, "#{table}_id_seq")
    end
  end

  # Get a new record and return its properties
  def get_record(table,id,what)
    dbh=db_connect()
    what="*" if what.nil?
    sth=dbh.prepare("SELECT #{what} FROM #{table} WHERE #{@index}=#{id}")
    sth.execute
    # The inject part is to convert string keys into symbols to optimize memory
    record=sth.fetch_hash
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
      sth=dbh.prepare("DELETE FROM #{@table} where #{@index}=#{props[:id]}")
      sth.execute
    end
  end

  # Quick access to the id of the datarecord
  def id
    @props[:id].to_i
  end

  # Update a datarecord into the database
  def update(values)
    db_connect() do |dbh|
      values.each do |field,value|
        value="'"+value.to_s+"'" if not value.is_a?(Integer)
        sth=dbh.prepare("UPDATE #{@table} set #{field}=#{value} WHERE #{@index}=#{id}")
        sth.execute
      end
    end
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

  # Creates a new dataset
  # - If props[:values] is given, then insert the dataset into the given table
  # - If props[:where] is given, then get the dataset from the database
  # - The table value may be coma separated list of tables (for joins)
  def initialize(table,props={})
    # Get a DB handler
    @dbh=db_connect()
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
  def fill(values,nodb=true)
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
    sth=@dbh.prepare("SELECT #{what} FROM #{table} WHERE #{where}")
    sth.execute
    result=[]
    sth.fetch_hash do |row|
      # The inject part is to convert string keys into symbols to optimize memory
      result << row.inject({}){|h,(k,v)| h[k.to_sym] = v; h}
    end
    return result
  end
  
  # Iterator
  def each
    @records.each do |record|
      yield record
    end
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
    sth=@dbh.prepare("DELETE FROM #{table} WHERE #{id_column} in (#{self.ids.join(',')})")
    sth.execute
  end
 
  # Same thing as delete, but also empty the dataset
  def delete!(table=@table)
    delete(table)
    @records=[]
  end

  # Update fields of the dataset into the database
  def update(values,table=@table,id_column="id")
    values.each_key do |field|
      values[field]="'"+values[field].to_s+"'" if not values[field].is_a?(Integer) 
      sth=@dbh.prepare("UPDATE #{table} SET #{field}=#{values[field]} WHERE #{id_column} in (#{self.ids.join(',')})")
      sth.execute
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

end
