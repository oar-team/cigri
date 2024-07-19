#require 'spec_helper'
require File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'api', 'cigri-api.rb')
require 'cigri'
require 'cigri-scheduler-affinity'
require 'test/unit'
require 'rack/test'
require 'sinatra'

Test::Unit::AutoRunner.need_auto_run = false if defined?(Test::Unit::AutoRunner)

set :environment, :test

cluster1 = "dahu"

describe 'API' do
  include Rack::Test::Methods

  def app
    @app ||= API
  end
  
  before(:each) do
    post '/campaigns', '{"name":"test_api", "nb_jobs":10,"clusters":{"'+cluster1+'":{"exec_file":"e"}}}', 'HTTP_X_CIGRI_USER' => 'Rspec'
    response = JSON.parse last_response.body
    @test_id = response['id']
  end

  after(:each) do
    db_connect do |dbh|
      delete_campaign(dbh, 'Rspec', @test_id)
    end
  end

  describe 'Scheduler' do

    describe 'SchedulerAffinity' do

      it "should add jobs to the runner queue" do
        campaigns=Cigri::Campaignset.new
        campaigns.get_running
        cluster_campaigns=campaigns.compute_campaigns_orders
        scheduler=Cigri::SchedulerAffinity.new(campaigns,cluster_campaigns)
        scheduler.do
        campaign=Cigri::Campaign.new(:id => @test_id)
        campaign.tasks(100,0).length.should == 10
      end

    end # SchedulerAffinity

  end # Scheduler

end

