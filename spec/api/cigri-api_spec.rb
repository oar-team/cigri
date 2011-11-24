require 'spec_helper'
require File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'api', 'cigri-api.rb')
require 'cigri'
require 'rack/test'
require 'sinatra'

set :environment, :test

describe 'API' do
  include Rack::Test::Methods

  def app
    @app ||= API
  end
  
  before(:all) do
    post '/campaigns', '{"name":"test_api", "nb_jobs":10,"clusters":{"fukushima":{"exec_file":"e"}}}', 'HTTP_X_CIGRI_USER' => 'Rspec'
    response = JSON.parse last_response.body
    @test_id = response['id']
  end

  after(:all) do
    db_connect do |dbh|
      delete_campaign(dbh, 'Rspec', @test_id)
    end
  end

  def check_headers(get=false, post=false, put=false, delete=false)
    last_response.header['Allow'].include?('GET').should be get
    last_response.header['Allow'].include?('POST').should be post
    last_response.header['Allow'].include?('PUT').should be put
    last_response.header['Allow'].include?('DELETE').should be delete
  end

  #WARNING: 
  def check_links(response)
    response['links'].should_not be nil
    response['links'].each do |link|
      link.include?('rel').should be true
      link.include?('href').should be true
    end
  end

  describe 'Success tests' do
    ['/', '/clusters'].each do |url|
      it "should success to get the url '#{url}'" do
        get '/'
        last_response.should be_ok
        response = JSON.parse last_response.body
        check_headers(get=true)
        check_links(response)
      end
    end

    it "should success to get the url '/campaigns'" do
      get '/campaigns'
      last_response.should be_ok
      response = JSON.parse last_response.body
      check_links(response)
      check_headers(get=true, post=true)
    end
    
    it 'should post a campaign' do
      post '/campaigns', '{"name":"test_api", "nb_jobs":10,"clusters":{"fukushima":{"exec_file":"e"}}}', 'HTTP_X_CIGRI_USER' => 'Rspec'
      response = JSON.parse last_response.body
      last_response.status.should be 201 
      last_response['Location'].should == "http://example.org/campaigns/#{response['id']}"
      check_links(response)
      db_connect do |dbh|
        delete_campaign(dbh, 'Rspec', response['id'])
      end
    end
    
    it 'should get info relative to an existing campaign' do
      get "/campaigns/#{@test_id}"
      last_response.should be_ok
      response = JSON.parse last_response.body
      %w{links total_jobs finished_jobs state user name submission_time id}.each do |key|
        response.has_key?(key).should be true
      end
      check_headers(get=true, post=true, put=true, delete=true)
      check_links(response)
    end
    
    xit 'should get info relative to the jobs posted campaign' do
      get "/campaigns/#{@test_id}/jobs"
      last_response.should be_ok
      response = JSON.parse(last_response.body)
      check_headers(get=true, post=true)
    end

    it 'should get the jdl of a campaign' do
      get "/campaigns/#{@test_id}/jdl"
      last_response.should be_ok
      response = JSON.parse(last_response.body)
      check_headers(get=true)
      %w{name clusters jobs_type params}.each do |field|
        response.has_key?(field).should be true
      end
    end
    
    describe 'Campaigns modifications' do
      before(:each) do
        post '/campaigns', '{"name":"test_api", "nb_jobs":10,"clusters":{"fukushima":{"exec_file":"e"}}}', 'HTTP_X_CIGRI_USER' => 'Rspec'
        @tmp_id = JSON.parse(last_response.body)['id']
      end

      after(:each) do
        db_connect do |dbh|
          delete_campaign(dbh, 'Rspec', @tmp_id)
        end
      end

      it 'should add more jobs in an existing campaign' do
        post "/campaigns/#{@tmp_id}/jobs", '["a", "b", "c", "d"]', 'HTTP_X_CIGRI_USER' => 'Rspec'
        last_response.status.should be 201
        last_response['Location'].should == "http://example.org/campaigns/#{@tmp_id}"
        response = JSON.parse last_response.body
        response['total_jobs'].should be 14
        check_links(response)
      end

      it 'should update a campaign' do
        put "/campaigns/#{@tmp_id}", {:name => :toto, :state => :paused} , 'HTTP_X_CIGRI_USER' => 'Rspec'
        last_response.should be_ok
        response = JSON.parse last_response.body
        response['name'].should == "toto"
        response['state'].should == "paused"
        check_links(response)
      end

      it 'should cancel a campaign' do
        delete "/campaigns/#{@tmp_id}", '', 'HTTP_X_CIGRI_USER' => 'Rspec'
        last_response.status.should be 202
        get "/campaigns/#{@tmp_id}"
        response = JSON.parse last_response.body
        response['state'].should == "cancelled"
      end
    end
  end

  describe 'Failure tests' do

    it 'should fail to get a non existing URL' do
      get '/toto'
      last_response.status.should be 404
    end

    it 'should fail to get the info relative to a non existing campaign' do
      get "/campaigns/-1"
      last_response.status.should be 404
    end

    it 'should fail to submit a campaign for an unauthorized user' do
      post '/campaigns', '{"name":"test_api", "nb_jobs":10,"clusters":{"fukushima":{"exec_file":"e"}}}', 'HTTP_X_CIGRI_USER' => 'unknown'
      last_response.status.should be 403
    end

    it 'should not add more jobs in a non existing campaign' do
      post "/campaigns/-1/jobs", '["a", "b", "c", "d"]', 'HTTP_X_CIGRI_USER' => 'Rspec'
      last_response.status.should be 404
    end

    it 'should not add more jobs in the campaign of someone else' do
      post "/campaigns/#{@test_id}/jobs", '["a", "b", "c", "d"]', 'HTTP_X_CIGRI_USER' => 'toto'
      last_response.status.should be 403
    end

    xit 'should not get non existing jobs from an existing campaign' do
      get "/campaigns/#{@test_id}/jobs/-1"
      last_response.status.should be 404
    end

    it 'should not get the jdl of a non existing campaign' do
      get "/campaigns/-1/jdl"
      last_response.status.should be 404
    end

    it 'should fail to update a non existing campaign' do
      put "/campaigns/-1", {:name => :toto, :state => :paused} , 'HTTP_X_CIGRI_USER' => 'Rspec'
      last_response.status.should be 404
    end

    it 'should fail to update someone else campaign' do
      put "/campaigns/#{@test_id}", {:name => :toto, :state => :paused} , 'HTTP_X_CIGRI_USER' => 'toto'
      last_response.status.should be 403
    end

    xit 'should not update any parameters' do

    end

    xit 'should fail to cancel a non existing campaign' do
    
    end

    xit 'should fail to cancel someone else campaign' do
    
    end

  end
end

