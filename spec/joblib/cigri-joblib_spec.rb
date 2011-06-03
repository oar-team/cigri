require 'cigri-joblib'
require 'dbi'
require 'spec_helper'


describe 'cigri-joblib' do
  describe 'Job' do
    before(:all) do
      db_connect() do |dbh|
        @job=Cigri::Job.new(:campaign_id => "100" , :state => "terminated")
      end
    end
    it 'should create a new job and return an id' do
      @job.id.should > 1
    end
    it 'should get back this job when the id is given' do
      job=Cigri::Job.new(:id => @job.id)
      job.props[:campaign_id].to_i.should == 100
    end
  end #  Job
  
end # cigri-joblib
