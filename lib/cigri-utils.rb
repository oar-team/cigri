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
#      dbh.do('INSERT .....')
#      ID = last_inserted_id(dbh)
#    end
##
def last_inserted_id(dbh)
  db = Cigri.conf.get('DATABASE_TYPE')
  if db.eql? 'Pg'
    id = dbh.execute("SELECT CURRVAL('$seq')")
    p id
  elsif db.eql? 'Mysql'
  
  else
    raise Cigri::Excaption, "impossible to retreive last inserted id: database type \"#{db}\" is not supported"
  end
end

#sub get_last_insert_id($$){
#    my $dbh = shift;
#    my $seq = shift;
#    
#    my $id;
#    my $sth;
#    if ($Db_type eq "Pg"){
#        $sth = $dbh->prepare("SELECT CURRVAL('$seq')");
#        $sth->execute();
#        my $ref = $sth->fetchrow_hashref();
#        my @tmp_array = values(%$ref);
#        $id = $tmp_array[0];
#        $sth->finish();
#    }else{
#        $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
#        $sth->execute();
#        my $ref = $sth->fetchrow_hashref();
#        my @tmp_array = values(%$ref);
#        $id = $tmp_array[0];
#        $sth->finish();
#    }

#    return($id);
#}
