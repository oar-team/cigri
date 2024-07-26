require 'spec_helper'
require File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'api', 'cigri-api.rb')
require 'cigri'
require 'test/unit'
require 'rack/test'
require 'sinatra'

Test::Unit::AutoRunner.need_auto_run = false if defined?(Test::Unit::AutoRunner)

set :environment, :test

describe 'API' do
  include Rack::Test::Methods

  def app
    @app ||= API
  end
  
  describe 'JWT tokens' do

    it 'should fail to add a token for a non-JWT enabled cluster (Security!)' do
      post "/tokens", '{"cluster_id" : 2, "token" : "Blah"}', 'HTTP_X_CIGRI_USER' => 'Rspec'
      last_response.status.should be 403
    end

    it 'should fail to remove a token for a non-JWT enabled cluster (Security!)' do
      delete "/tokens/2"
      last_response.status.should be 403
    end

    it 'should add or update a token' do
      delete "/tokens/10"
      post "/tokens", '{"cluster_id" : 10, "token" : "Blah"}', 'HTTP_X_CIGRI_USER' => 'Rspec'
      last_response.status.should be 201
      post "/tokens", '{"cluster_id" : 10, "token" : "Blah"}', 'HTTP_X_CIGRI_USER' => 'Rspec'
      last_response.status.should be 201
    end

    it 'should list tokens' do
      get "/tokens",'', 'HTTP_X_CIGRI_USER' => 'Rspec'
      last_response.status.should be 200
      response = JSON.parse last_response.body
      response['items'][0]['cluster_login'].should == "Bearer Blah"
    end

    it 'should delete a token' do
      delete "/tokens/10",'','HTTP_X_CIGRI_USER' => 'Rspec'
      last_response.status.should be 202
    end

  end
end

