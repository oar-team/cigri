require File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'api', 'cigri-api.rb')
require 'cigri'
require 'spec_helper'
require 'rack/test'
require 'sinatra'

set :environment, :test

def app
  API
end

describe 'API' do
  include Rack::Test::Methods
    
  ['/', '/clusters', '/campaigns'].each do |url|
    it "should success to get the url '#{url}'" do
      get url
      last_response.should be_ok
      response = JSON.parse last_response.body
      links = response['links']
      links.should_not be nil
    end
  end
  
  it 'should post a campaign' do
    post '/campaigns', '{"name":"test_api", "nb_jobs":10,"clusters":{"fukushima":{"exec_file":"e"}}}', 'HTTP_X_CIGRI_USER' => 'Rspec'
    response = JSON.parse last_response.body
    last_response.status.should be(201)
    db_connect do |dbh|
      delete_campaign(dbh, 'Rspec', response['id'])
    end
  end
  
  
  describe 'Interactive commands' do
    before(:all) do
      post '/campaigns', '{"name":"test_api", "nb_jobs":10,"clusters":{"fukushima":{"exec_file":"e"}}}', 'HTTP_X_CIGRI_USER' => 'Rspec'
      response = JSON.parse last_response.body
      @test_id = response['id']
    end
    
    it 'should get info relative to the posted campaign' do
      get "/campaigns/#{@test_id}"
      last_response.should be_ok
      response = JSON.parse last_response.body
      links = response['links']
      links.should_not be nil
    end
    
    it 'should add more jobs in an existing campaign' do
      post "/campaigns/#{@test_id}/jobs", '["a", "b", "c", "d"]', 'HTTP_X_CIGRI_USER' => 'Rspec'
      response = JSON.parse last_response.body
      response['total_jobs'].should be == 14
    end

    it 'should not add more jobs in a non existing campaign' do
      post "/campaigns/1234567890/jobs", '["a", "b", "c", "d"]', 'HTTP_X_CIGRI_USER' => 'Rspec'
      last_response.status.should be(404)
    end

    it 'should not add more jobs in the campaign of someone else' do
      post "/campaigns/#{@test_id}/jobs", '["a", "b", "c", "d"]', 'HTTP_X_CIGRI_USER' => 'toto'
      last_response.status.should be(403)
    end
    
    xit 'should get info relative to the jobs posted campaign' do
      get "/campaigns/#{@test_id}/jobs"
      last_response.should be_ok
      response = JSON.parse last_response.body
      links = response['links']
      links.should_not be nil
    end
    
    after(:all) do
      db_connect do |dbh|
        delete_campaign(dbh, 'Rspec', @test_id)
      end
    end
  end
end

