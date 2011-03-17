def db_connect()
  dbh = DBI.connect("DBI:#{DB_TYPE}:cigri:localhost", 'cigri', 'cigri')
  return dbh unless block_given?
  yield dbh
  dbh.disconnect()
end
