require 'cigri-conflib'
require 'dbi'

def db_connect()
  config = Cigri::Conf.new
  str = "DBI:#{config.get('DATABASE_TYPE')}:#{config.get('DATABASE_NAME')}:#{config.get('DATABASE_HOST')}"
  dbh = DBI.connect(str, 
                    "#{config.get('DATABASE_USER_NAME')}", 
                    "#{config.get('DATABASE_USER_PASSWORD')}")
  return dbh unless block_given?
  yield dbh
  dbh.disconnect()
end
