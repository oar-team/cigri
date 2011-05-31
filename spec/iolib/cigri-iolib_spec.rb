require 'cigri-iolib'
require 'dbi'
require 'json'
require 'spec_helper'

CORRECT_JSON = JSON.parse('{"name":"Some campaign","jobs_type":"normal","clusters":{"tchernobyl":{"exec_directory":"$HOME","temporal_grouping":"true","checkpointing_type":"None","exec_file":"$HOME/script.sh","walltime":"01:00:00","output_gathering_method":"scp","resources":"nodes=1","type":"best-effort","dimensional_grouping":"false","output_destination":"my.dataserver.fr","properties":""},"fukushima":{"exec_directory":"$HOME","temporal_grouping":"true","checkpointing_type":"None","exec_file":"$HOME/path/script","walltime":"01:00:00","output_gathering_method":"scp","resources":"nodes=1","type":"best-effort","dimensional_grouping":"false","output_destination":"my.dataserver.fr","properties":""},"my.other_cluster.fr":{"exec_directory":"$HOME","temporal_grouping":"true","checkpointing_type":"None","exec_file":"$HOME/script.sh","walltime":"01:00:00","output_gathering_method":"scp","resources":"nodes=1","type":"best-effort","dimensional_grouping":"false","output_destination":"my.dataserver.fr","properties":""}},"params":["0","1"]}')

describe 'cigri-iolib' do
  before(:all) do
    @old_db = Cigri.conf.get('DATABASE_TYPE')
  end
  after(:each) do
    Cigri.conf.conf['DATABASE_TYPE'] = @old_db
  end
  #%w{Pg Mysql}.each do |db_type|
  %w{Pg}.each do |db_type|
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
        get_cluster_id(dbh, 'tchernobyl').should be_a(Integer)
      end
    end
    it 'should return nil if the cluster does not exist' do
      db_connect() do |dbh|
        get_cluster_id(dbh, 'suihfduighuisd').should == nil
      end
    end
  end # get_cluster_id
  
  describe 'get_clusters_ids' do
    it 'should return an empty hash if no clusters are passed' do
      db_connect() do |dbh|
        get_clusters_ids(dbh, []).should == {}
      end
    end
    it 'should return a hash ID if the clusters exists' do
      db_connect() do |dbh|
        res = get_clusters_ids(dbh, %w{tchernobyl threemile non_existing.cluster})
        res.should be_a(Hash)
        res.size.should == 2
      end
    end
    it 'should return an empty hash if the clusters does not exist' do
      db_connect() do |dbh|
        get_clusters_ids(dbh, %w{suihf  duighuisd}).should == {}
      end
    end
  end # get_cluster_id
  
  describe 'cigri_submit' do
    it 'should submit a campaign' do
      db_connect() do |dbh|
        id = cigri_submit(dbh, CORRECT_JSON, 'kameleon')
        id.should be_a(Integer)
        delete_campaign(dbh, 'kameleon', id)
      end
    end
    
    it 'should fail to submit if json not correct' do
      db_connect() do |dbh|
        lambda{cigri_submit(dbh, '', 'kameleon')}.should raise_error DBI::ProgrammingError
      end
    end
  end # cigri_submit
  
  describe 'delete_campaign' do
    it 'should delete an existing campaign' do
      db_connect() do |dbh|
      
        id = cigri_submit(dbh, CORRECT_JSON, 'kameleon')
        delete_campaign(dbh, 'kameleon', id).should == true
      end
    end
    
    it 'should fail to delete an non existing campaign' do
      db_connect() do |dbh|
        delete_campaign(dbh, 'kameleon', -1).should == nil
      end
    end
    
    it 'should fail to delete a campaign when the wrong owner asks' do
      db_connect() do |dbh|
        id = cigri_submit(dbh, CORRECT_JSON, 'kameleon')
        delete_campaign(dbh, 'toto', id).should == false
      end
    end
    
  end # delete_campaign
  
  describe 'get_running_campaigns' do
    it 'should return an array' do
      db_connect() do |dbh|
        get_running_campaigns(dbh).should be_a(Array)
      end
    end
  end # get_running_campaigns
  
end # cigri-iolib
