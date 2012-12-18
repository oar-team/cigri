#require 'spec_helper'
require 'cigri-joblib'
require 'dbi'

describe 'cigri-joblib' do
  describe 'Job without database fetching' do
    before(:all) do
      @job = Cigri::Job.new(:id => 9999999999999, 
                            :campaign_id => 9999999 , 
                            :state => "terminated", 
                            :nodb => true,
                            :param_id => 0)
    end
    it 'should return the provided job id' do
      @job.id.should == 9999999999999
    end
    it 'should return the provided campaign_id' do
      @job.props[:campaign_id].should == 9999999
    end
  end

  describe 'Job from database' do
    before(:all) do
      db_connect() do |dbh|
        @job = Cigri::Job.new(:campaign_id => 100 , :state => "terminated", :param_id => 0)
      end
    end
    it 'should create a new job and return an id' do
      @job.id.should > 1
    end
    it 'should get back this job when the id is given' do
      job = Cigri::Job.new(:id => @job.id)
      job.props[:campaign_id].to_i.should == 100
    end
    it 'should be able to delete itself from the database' do
      lambda { @job.delete }.should_not raise_error Exception
    end
    it 'should have deleted the job' do
      job = Cigri::Job.new(:id => @job.id)
      job.props.should be_nil
    end
  end #  Job

  describe 'Jobset' do
    before(:all) do
      campaign = Datarecord.new('campaigns', :grid_user => "obiwan", :state => "terminated", :type => "none")
      param = Datarecord.new('parameters', :campaign_id => campaign.id)
      j1 = Cigri::Job.new(:campaign_id => campaign.id, :state => "to_launch", :node_name => "obiwan1", :param_id => param.props[:id])
      j2 = Cigri::Job.new(:campaign_id => campaign.id, :state => "to_launch", :node_name => "obiwan2", :param_id => param.props[:id])
      @jobs=Cigri::Jobset.new(:where => "jobs.node_name like 'obiwan%'")
      j1.delete
      j2.delete
      param.delete
      @campaign_id=campaign.id
      campaign.delete
    end
    it 'should have a length of 2' do
      @jobs.length.should == 2
    end
    it 'should return 2 jobs' do
      count=0
      @jobs.each do |job|
        count += 1 if job.props[:campaign_id].to_i == @campaign_id
      end
      count.should == 2
    end
    it 'should return an array of ids' do
      @jobs.ids.should be_an(Array)
    end
    it 'should have integers into the array of ids' do
      @jobs.ids[0].should be_an(Integer)
    end
  end 
 
  describe 'Campaignset' do
    before(:all) do
      @campaign1 = Datarecord.new('campaigns', :grid_user => "obiwan", :state => "in_treatment", :type => "none")
      @property11 = Datarecord.new('campaign_properties', :cluster_id => 1, 
                                                :campaign_id => @campaign1.id,
                                                :name => "obiwan",
                                                :value => "kenobi")
      @property12 = Datarecord.new('campaign_properties', :cluster_id => 2, 
                                                :campaign_id => @campaign1.id,
                                                :name => "obiwan",
                                                :value => "kenobi")
      @campaign2 = Datarecord.new('campaigns', :grid_user => "yoda", :state => "in_treatment", :type => "none")
      @property21 = Datarecord.new('campaign_properties', :cluster_id => 2, 
                                                :campaign_id => @campaign2.id,
                                                :name => "obiwan",
                                                :value => "kenobi")
      @property22 = Datarecord.new('campaign_properties', :cluster_id => 3, 
                                                :campaign_id => @campaign2.id,
                                                :name => "obiwan",
                                                :value => "kenobi")
      @campaign_set=Cigri::Campaignset.new()
      @campaign_set.get_running
    end

    after(:all) do 
      @campaign1.delete
      @campaign2.delete
      @property11.delete
      @property12.delete
      @property21.delete
      @property22.delete
     end

     it 'should contain 2 running campaigns' do
       @campaign_set.length.should == 2
     end

     it 'should contain 3 clusters' do
       cluster_cache=@campaign_set.get_clusters
       cluster_cache.length.should == 3
     end
  
     it 'should compute couples orders' do
       lambda { couples=@campaign_set.compute_orders }.should_not raise_error Exception
     end

     it 'should return 4 couples' do
       @campaign_set.compute_orders.length.should == 4
     end

     context 'when a cluster is stressed' do
       it 'should return 2 couples' do
         cluster=Datarecord.new('clusters',:id => 2)
         cluster.props[:stress_factor]=1.2
         cluster.update(cluster.props)
         @campaign_set.compute_orders.length.should == 2
         cluster.props[:stress_factor]=0
         cluster.update(cluster.props)
       end
     end

     it 'should be fifo by default' do
       @campaign_set.compute_orders.should == 
          [[1,@campaign1.id],[2,@campaign1.id],[2,@campaign2.id],[3,@campaign2.id]]
     end

     it 'should place yoda before obiwan if yoda is the best' do
       @prio=Datarecord.new('users_priority',
                            :grid_user => "yoda", :cluster_id => 2, :priority => 10)
       begin
         @campaign_set.compute_orders.should ==
            [[1,@campaign1.id],[2,@campaign2.id],[2,@campaign1.id],[3,@campaign2.id]]
       rescue
         raise
       ensure
         @prio.delete
       end
     end

  end
  
end # cigri-joblib
