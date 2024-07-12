#require 'spec_helper'
require File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'api', 'cigri-api.rb')
require 'cigri'
require 'test/unit'
require 'rack/test'
require 'sinatra'

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

#  after(:each) do
#    db_connect do |dbh|
#      delete_campaign(dbh, 'Rspec', @test_id)
#    end
#  end

  def check_headers(get=false, post=false, put=false, delete=false)
    last_response.header['Allow'].include?('GET').should be get
    last_response.header['Allow'].include?('POST').should be post
    last_response.header['Allow'].include?('PUT').should be put
    last_response.header['Allow'].include?('DELETE').should be delete
  end

  def check_links(response, prefix='/')
    response['links'].should_not be nil
    response['links'].each do |link|
      link.include?('rel').should be true
      link.include?('href').should be true
      link['href'].start_with?(prefix).should be true
    end
  end

  def check_job(job)
    %w{href state name id parameters}.each do |key|       
      job.has_key?(key).should be true
    end
  end

  def check_jobs(jobs, offset=0, limit=10)
    jobs.class.should == Hash
    %w{total items offset}.each do |key|
      jobs.has_key?(key).should be true
    end
    jobs['total'].should be 10
    jobs['items'].length.should be limit
    jobs['items'].each do |job|
      check_job(job)
      #(offset...(offset+limit)).include?(job['id']).should be true
    end
  end

  describe 'GET' do

    describe 'Success' do

      ['/', '/clusters'].each do |url|
        it "should get the url '#{url}'" do
          get '/'
          last_response.should be_ok
          response = JSON.parse last_response.body
          check_headers(get=true)
          check_links(response)
        end
      end

      it "should get the url '/campaigns'" do
        get '/campaigns'
        last_response.should be_ok
        response = JSON.parse last_response.body
        check_links(response)
        check_headers(get=true, post=true)
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

      it 'should get info relative to the jobs posted campaign' do
        get "/campaigns/#{@test_id}/jobs"
        last_response.should be_ok
        check_jobs(JSON.parse(last_response.body))
        check_headers(get=true, post=true)
      end

      it 'should get info relative to the jobs of a campaign with custom limit and offset' do
        get "/campaigns/#{@test_id}/jobs?limit=2&offset=2"
        last_response.should be_ok

        check_jobs(JSON.parse(last_response.body), 2, 2)
        check_headers(get=true, post=true)
      end

      it 'should get info on a specific job of a campaign' do
        get "/campaigns/#{@test_id}/jobs/2"
        last_response.should be_ok
        check_job(JSON.parse(last_response.body))
        check_headers(get=true)
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

      it 'should get the urls with a prefix' do
        get "/", 'HTTP_X_CIGRI_API_PATH_PREFIX' => 'prefix'
        last_response.should be_ok
        check_links(JSON.parse(last_response.body), '/prefix')
        get "/campaigns/#{@test_id}", 'HTTP_X_CIGRI_API_PATH_PREFIX' => 'prefix'
        last_response.should be_ok
        check_links(JSON.parse(last_response.body), '/prefix')
      end
      
    end # Success

    describe 'Failure' do

      it 'should fail to get a non existing URL' do
        get '/toto'
        last_response.status.should be 404
      end

      it 'should fail to get the info relative to a non existing campaign' do
        get "/campaigns/-1"
        last_response.status.should be 404
      end

      it 'should fail to get the info relative to a campaign using a string as ID' do
        get "/campaigns/toto"
        last_response.status.should be 404
      end

      it 'should not get non existing jobs from an existing campaign' do
        get "/campaigns/#{@test_id}/jobs/123456789"
        last_response.status.should be 404
      end

      it 'should not get the jdl of a non existing campaign' do
        get "/campaigns/-1/jdl"
        last_response.status.should be 404
      end

    end # Failure

  end # GET

  describe 'POST' do

    describe 'Success' do

      it 'should post a campaign' do
      post '/campaigns', '{"name":"test_api", "nb_jobs":10,"clusters":{"'+cluster1+'":{"exec_file":"e"}}}', 'HTTP_X_CIGRI_USER' => 'Rspec'
        response = JSON.parse last_response.body
        last_response.status.should be 201 
        last_response['Location'].should == "/campaigns/#{response['id']}"
        check_links(response)
        db_connect do |dbh|
          delete_campaign(dbh, 'Rspec', response['id'])
        end
      end

      it 'should add more jobs in an existing campaign' do
        post "/campaigns/#{@test_id}/jobs", '["a", "b", "c", "d"]', 'HTTP_X_CIGRI_USER' => 'Rspec'
        last_response.status.should be 201
        last_response['Location'].should == "/campaigns/#{@test_id}"
        response = JSON.parse last_response.body
        response['total_jobs'].should be 14
        check_links(response)
      end

    end # Success

    describe 'Failure' do

      it 'should fail to submit a campaign for an unauthorized user' do
        post '/campaigns', '{"name":"test_api", "nb_jobs":10,"clusters":{"'+cluster1+'":{"exec_file":"e"}}}', 'HTTP_X_CIGRI_USER' => 'unknown'
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

    
    end # Failure

  end # POST

  describe 'PUT' do

    describe 'Success' do

      it 'should update a campaign' do
        put "/campaigns/#{@test_id}", {:name => :toto, :state => :paused} , 'HTTP_X_CIGRI_USER' => 'Rspec'
        last_response.status.should be 202
        response = JSON.parse last_response.body
        response['name'].should == "toto"
        response['state'].should == "paused"
        check_links(response)
      end

    end # Success

    describe 'Failure' do

      it 'should fail to update a non existing campaign' do
        put "/campaigns/-1", {:name => :toto, :state => :paused} , 'HTTP_X_CIGRI_USER' => 'Rspec'
        last_response.status.should be 404
      end

      it 'should fail to update someone else campaign' do
        put "/campaigns/#{@test_id}", {:name => :toto, :state => :paused} , 'HTTP_X_CIGRI_USER' => 'toto'
        last_response.status.should be 403
      end

      xit 'should not update any parameters'

    end # Failure

  end # PUT

  describe 'DELETE' do

    describe 'Success' do
    
      it 'should cancel a campaign' do
        delete "/campaigns/#{@test_id}", '', 'HTTP_X_CIGRI_USER' => 'Rspec'
        last_response.status.should be 202
        get "/campaigns/#{@test_id}"
        response = JSON.parse last_response.body
        response['state'].should == "cancelled"
      end
    end # Success
    
    describe 'Failure' do

      it 'should fail to cancel a non existing campaign' do
        delete "/campaigns/-1", '', 'HTTP_X_CIGRI_USER' => 'Rspec'
        last_response.status.should be 404
      end

      it 'should fail to cancel someone else campaign' do
        delete "/campaigns/#{@test_id}", '', 'HTTP_X_CIGRI_USER' => 'toto'
        last_response.status.should be 403
      end

    end # Failure

  end # DELETE

end

