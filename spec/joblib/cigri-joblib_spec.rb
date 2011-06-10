require 'cigri-joblib'
require 'dbi'
require 'spec_helper'


describe 'cigri-joblib' do

  describe 'Job without database fetching' do
    before(:all) do
      @job=Cigri::Job.new(:id=> 9999999999999, 
                          :campaign_id => 9999999 , 
                          :state => "terminated", 
                          :nodb => true)
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
        @job=Cigri::Job.new(:campaign_id => 100 , :state => "terminated")
      end
    end
    it 'should create a new job and return an id' do
      @job.id.should > 1
    end
    it 'should get back this job when the id is given' do
      job=Cigri::Job.new(:id => @job.id)
      job.props[:campaign_id].to_i.should == 100
    end
    it 'should be able to delete itself from the database' do
      lambda { @job.delete }.should_not raise_error Exception
    end
    it 'should have deleted the job' do
      job=Cigri::Job.new(:id => @job.id)
      job.props.should be_nil
    end
  end #  Job

  describe 'Jobset' do
    it 'should return 2 jobs' do
      j1=Cigri::Job.new(:campaign_id => 9999998, :state => "to_launch", :name => "obiwan1")
      j2=Cigri::Job.new(:campaign_id => 9999998, :state => "to_launch", :name => "obiwan2")
      jobs=Cigri::Jobset.new(:where => "name like 'obiwan%'")
      j1.delete
      j2.delete
      count=0
      jobs.each do |job|
        count += 1 if job.props[:campaign_id].to_i == 9999998
      end
      count.should == 2
    end
  end 
  
end # cigri-joblib
