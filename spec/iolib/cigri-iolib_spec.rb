require 'cigri-iolib'
require 'dbi'
require 'spec_helper'

describe 'cigri-iolib' do
  before(:all) do
    @old_db = Cigri.conf.get('DATABASE_TYPE')
  end
  after(:each) do
    Cigri.conf.conf['DATABASE_TYPE'] = @old_db
  end
  %w{Pg Mysql}.each do |db_type|

    describe "#{db_type}" do
      before(:each) do
        Cigri.conf.conf['DATABASE_TYPE'] = db_type
      end
      
      describe 'db_connect' do
        it 'should return a database handle when not given a block' do
          dbh = db_connect()
          dbh.should be_a(DBI::DatabaseHandle)
          dbh.disconnect()
        end
        it 'should return a database handle in a block' do
          db_connect() do |dbh|
            dbh.should be_a(DBI::DatabaseHandle)
          end
        end
        it 'should fail for unknown driver' do
          Cigri.conf.conf['DATABASE_TYPE'] = 'TOTO'
          lambda{db_connect()}.should raise_error DBI::InterfaceError
        end
      end # db_connect
    end # db_type
  end # %w{}.each
  
  describe 'get_cluster_id' do
    it 'should return an ID if the cluster exists' do
      db_connect() do |dbh|
        get_cluster_id(dbh, 'my.cluster.fr').should be_a(Integer)
      end
    end
    it 'should return nil if the cluster does not exist' do
      db_connect() do |dbh|
        get_cluster_id(dbh, 'suihfduighuisd').should == nil
      end
    end
  end # get_cluster_id
end # cigri-iolib
