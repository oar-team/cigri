#require 'spec_helper'
require 'json'

require 'cigri-iolib'
require 'cigri-joblib'

CORRECT_JSON_STRING = '{"name":"Some campaign","jobs_type":"normal","clusters":{"tchernobyl":{"exec_directory":"$HOME","temporal_grouping":"true","checkpointing_type":"None","exec_file":"$HOME/script.sh","walltime":"01:00:00","output_gathering_method":"scp","resources":"nodes=1","type":"best-effort","dimensional_grouping":"false","output_destination":"my.dataserver.fr","properties":""},"fukushima":{"exec_directory":"$HOME","temporal_grouping":"true","checkpointing_type":"None","exec_file":"$HOME/path/script","walltime":"01:00:00","output_gathering_method":"scp","resources":"nodes=1","type":"best-effort","dimensional_grouping":"false","output_destination":"my.dataserver.fr","properties":""},"my.other_cluster.fr":{"exec_directory":"$HOME","temporal_grouping":"true","checkpointing_type":"None","exec_file":"$HOME/script.sh","walltime":"01:00:00","output_gathering_method":"scp","resources":"nodes=1","type":"best-effort","dimensional_grouping":"false","output_destination":"my.dataserver.fr","properties":""}},"params":["0","1"]}'

describe 'cigri-iolib' do
  before(:all) do
    @old_db = Cigri.conf.get('DATABASE_TYPE')
  end
  before(:each) do
    @correct_json = JSON.parse(CORRECT_JSON_STRING)
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
        nb_params = @correct_json['params'].length
        id = cigri_submit(dbh, @correct_json, 'kameleon')
        id.should be_a(Integer)
        query = "SELECT count(*) 
                 FROM parameters AS p, bag_of_tasks as b 
                 WHERE p.id = b.param_id AND 
                       p.campaign_id = b.campaign_id AND
                       p.campaign_id = ?"
        nb_jobs = dbh.select_one(query, id)[0].should be == nb_params
        delete_campaign(dbh, 'kameleon', id)
      end
    end
    
    it 'should fail to submit if json not correct' do
      db_connect() do |dbh|
        lambda{cigri_submit(dbh, '', 'kameleon')}.should raise_error
      end
    end
  end # cigri_submit

  describe "cigri_submit_jobs" do
    it 'should fail if campaign does not exist' do
      db_connect() do |dbh|
        lambda{cigri_submit_jobs(dbh, ["param1 a", "param2 b"], 123456789, 'user')}.should raise_error Cigri::Error
      end
    end

    it 'should fail if campaign is cancelled' do
      db_connect() do |dbh|
        id = cigri_submit(dbh, @correct_json, 'kameleon')
        dbh.do("UPDATE campaigns SET state = 'cancelled' WHERE id = ?", id)
        lambda{cigri_submit_jobs(dbh, ["param1 a", "param2 b"], id, 'user')}.should raise_error Cigri::Error
        delete_campaign(dbh, 'kameleon', id)
      end
    end

    it 'should fail if campaign does not belong to the user' do
      db_connect() do |dbh|
        id = cigri_submit(dbh, @correct_json, 'kameleon')
        dbh.do("UPDATE campaigns SET state = 'cancelled' WHERE id = ?", id)
        lambda{cigri_submit_jobs(dbh, ["param1 a", "param2 b"], id, 'user')}.should raise_error Cigri::Error
        delete_campaign(dbh, 'kameleon', id)
      end
    end

    it 'should change a campaign from terminated to in_treatment' do
      db_connect() do |dbh|
        nb_params = @correct_json['params'].length
        id = cigri_submit(dbh, @correct_json, 'kameleon')
        dbh.do("UPDATE campaigns SET state = 'terminated' WHERE id = ?", id)
        lambda{cigri_submit_jobs(dbh, ["param1 a", "param2 b"], id, 'kameleon')}.should_not raise_error
        dbh.select_one("SELECT state FROM campaigns WHERE id = ?", id)[0].should be == "in_treatment"
        dbh.select_one("SELECT count(*) FROM bag_of_tasks WHERE campaign_id = ?", id)[0].should be == nb_params + 2
        delete_campaign(dbh, 'kameleon', id)
      end
    end
  end # cigri_submit_jobs
  
  describe 'cancel_campaign' do
    it 'should cancel an existing campaign' do
      db_connect() do |dbh|
        id = cigri_submit(dbh, @correct_json, 'kameleon')
        cancel_campaign(dbh, 'kameleon', id).should be == 1
        campaign = Cigri::Campaign.new({:id => id})
        campaign.props[:state].should be == 'cancelled'
        delete_campaign(dbh, 'kameleon', id)
      end
    end
    
    it 'should cancel an existing campaign only once' do
      db_connect() do |dbh|
        id = cigri_submit(dbh, @correct_json, 'kameleon')
        cancel_campaign(dbh, 'kameleon', id).should be == 1
        cancel_campaign(dbh, 'kameleon', id).should be == 0
        campaign = Cigri::Campaign.new({:id => id})
        campaign.props[:state].should be == 'cancelled'
        delete_campaign(dbh, 'kameleon', id)
      end
    end
    
    it 'should fail to cancel a non existing campaign' do
      db_connect() do |dbh|
        lambda{cancel_campaign(dbh, 'kameleon', -1)}.should raise_error Cigri::NotFound
      end
    end
    
    it 'should fail to cancel a campaign when the wrong owner asks' do
      db_connect() do |dbh|
        id = cigri_submit(dbh, @correct_json, 'kameleon')
        lambda{cancel_campaign(dbh, 'toto', id)}.should raise_error Cigri::Unauthorized
        delete_campaign(dbh, 'kameleon', id)
      end
    end
    
  end # cancel_campaign
  
  describe 'delete_campaign' do
    it 'should delete an existing campaign' do
      db_connect() do |dbh|
        id = cigri_submit(dbh, @correct_json, 'kameleon')
        delete_campaign(dbh, 'kameleon', id).should == true
      end
    end
    
    it 'should fail to delete a non existing campaign' do
      db_connect() do |dbh|
        lambda{delete_campaign(dbh, 'kameleon', -1)}.should raise_error Cigri::NotFound
      end
    end
    
    it 'should fail to delete a campaign when the wrong owner asks' do
      db_connect() do |dbh|
        id = cigri_submit(dbh, @correct_json, 'kameleon')
        lambda{delete_campaign(dbh, 'toto', id)}.should raise_error Cigri::Unauthorized
        delete_campaign(dbh, 'kameleon', id)
      end
    end
    
  end # delete_campaign

  describe 'take_tasks' do
    xit 'should test take_tasks' do
    end
  end # take tasks
  
  describe 'get_running_campaigns' do
    it 'should return an array' do
      db_connect() do |dbh|
        get_running_campaigns(dbh).should be_a(Array)
      end
    end
  end # get_running_campaigns

  describe 'Datarecord' do
    before(:all) do
      db_connect() do |dbh|
        @job = Datarecord.new('jobs', :campaign_id => "100" , :state => "terminated", :param_id => 0)
      end
    end
    it 'should create a new record into the job table and return an id' do
      @job.id.should >= 1
    end
    it 'should get back this record from the database when the id is given' do
      job = Datarecord.new('jobs', :id => @job.id)
      job.props[:campaign_id].to_i.should == 100
    end
    it 'should be able to delete itself from the database' do
      lambda { @job.delete }.should_not raise_error Exception
    end
    it 'should have nil props for a non existant record' do
      toto = Datarecord.new('jobs', :id => '-1').props.should == nil
    end

  end #  Datarecord
  
end # cigri-iolib
