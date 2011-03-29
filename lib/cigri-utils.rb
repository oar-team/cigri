require 'cigri-conflib'

config=Cigri::Conf.new

def db_connect()
  db_conn = 
  dbh = DBI.connect("DBI:#{config.get('DATABASE_TYPE')}:#{config.get('DATABASE_NAME')}:#{config.get('DATABASE_HOST')}", 
                    "#{config.get('DATABASE_USER_NAME')}", 
                    "#{config.get('DATABASE_USER_PASSWORD')}")
  return dbh unless block_given?
  yield dbh
  dbh.disconnect()
end
