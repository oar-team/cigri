require 'cigri-conflib'
require 'dbi'

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
  config = Cigri.conf
  str = "DBI:#{config.get('DATABASE_TYPE')}:#{config.get('DATABASE_NAME')}:#{config.get('DATABASE_HOST')}"
  dbh = DBI.connect(str, 
                    "#{config.get('DATABASE_USER_NAME')}", 
                    "#{config.get('DATABASE_USER_PASSWORD')}")
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
def last_inserted_id(dbh, seqname)
  db = Cigri.conf.get('DATABASE_TYPE')
  if db.eql? 'Pg'
    row = dbh.select_one("SELECT currval('#{seqname}')")
  elsif db.eql? 'Mysql'
    row = dbh.select_one("SELECT LAST_INSERT_ID()")
  else
    raise Cigri::Excaption, "impossible to retreive last inserted id: database type \"#{db}\" is not supported"
  end
  return row[0]
end
