require 'spec_helper'
require File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'api', 'cigri-api.rb')
require 'cigri'
require 'test/unit'
require 'rack/test'
require 'sinatra'

set :environment, :test

Test::Unit::AutoRunner.need_auto_run = false if defined?(Test::Unit::AutoRunner)

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

  describe 'Events' do

      it 'should create a new event' do
        event=Cigri::Event.new(:class => 'notify', :state => 'closed', :campaign_id => @test_id, :code => 'DUMMY_EVENT')
        event.props[:state].should == 'closed'
      end

      it 'should get events for a campaign' do
        Cigri::Event.new(:class => 'notify', :state => 'closed', :campaign_id => @test_id, :code => 'DUMMY_EVENT')
        campaign = Cigri::Campaign.new({:id => @test_id})
        campaign.events(10,0,1)[0][8].should == 'closed'
      end

      it 'should get a global event and close it' do
        event=Cigri::Event.new(:class => 'notify', :state => 'open', :code => 'DUMMY_EVENT')
        events=[]
        db_connect do |dbh|
          events=get_global_events(dbh, 10, 0)
        end
        events[0][8].should be == 'open'
        event.close()
        event=Cigri::Event.new(:id => event.id)
        event.props[:state].should == 'closed'
      end


  end # Events

end

