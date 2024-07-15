#require 'spec_helper'
require 'cigri-restclientlib'
require 'cigri-clusterlib'
require 'cigri-colombolib'
require 'rdbi'
require 'json'
require 'yaml'

describe 'cigri-restclientlib (RestSession)' do
  #  describe "Initialize" do
  #    it 'should not raise error' do
  #      lambda{Cigri::RestSession.new({"api_url" => "http://localhost/oarapi/",
  #                                     "api_auth_type"=>"cert"},
  #                                      "application/json")}.should_not raise_error Exception
  #    end
  #    it 'should have a root ok in JSON' do
  #      rest=Cigri::RestSession.new({"api_url" => "http://localhost/oarapi/",
  #                                     "api_auth_type"=>"cert"},
  #                                          "application/json")
  #      lambda{rest.get("")}.should_not raise_error Exception
  #    end
  #    it 'should have a root ok in YAML' do
  #      rest=Cigri::RestSession.new({"api_url" => "http://localhost/oarapi/",
  #                                  "api_auth_type"=>"cert"},
  #                                                "text/yaml")
  #      lambda{rest.get("")}.should_not raise_error Exception
  #    end
  #    it 'should work with a username/passwd' do
  #      rest=Cigri::RestSession.new({"api_url" => "http://localhost/oarapi/",
  #                                  "api_auth_type"=>"password",
  #                                  "api_username" => "kameleon",
  #                                  "api_password" => "kameleon"},
  #                                                 "text/yaml")
  #      lambda{rest.get("")}.should_not raise_error Exception
  #    end
  # end
  describe "Collection" do
    before(:all) do
      @rest=Cigri::RestSession.new({"api_url" => "https://f-dahu.u-ga.fr:6669/oarapi-cigri/",
                                  "api_auth_type"=>"password",
                                  "api_username" => "kameleon",
                                  "api_password" => "kameleon",
                                  "api_auth_type" => "cert"},
                                       "application/json")
    end
    it 'should return an array' do
      @rest.get_collection("resources").should be_an(Array)
    end
    it 'should manage paginated collection' do
      @rest.get_collection("resources?limit=10").length.should > 10
    end
 end

end

describe 'cigri-clusterlib (Cluster)' do
  describe "Initialize" do
    it 'should not succeed when no arg given' do
      lambda{Cigri::Cluster.new()}.should raise_error Exception
    end
    it 'should not succeed when an invalid cluster name is given' do
      lambda{Cigri::Cluster.new(:name => "non_existent.cluster")}.should raise_error Exception
    end
    it 'should succeed when the name of a valid cluster is given' do
      lambda{Cigri::Cluster.new(:name => "dahu")}.should_not raise_error Exception
    end
    it 'should succeed when the id of a valid cluster is given' do
      lambda{Cigri::Cluster.new(:id => 2)}.should_not raise_error Exception
    end
  end # Initialize

  describe "Tchernobyl resources" do
    before(:all) do
      @cluster=Cigri::Cluster.new(:name => "dahu")
    end
    it 'should return an array' do
      @cluster.get_resources.should be_an(Array)
    end
  end # Resources check
  
  describe "Job submission" do
    before(:all) do
      @cluster=Cigri::Cluster.new(:name => "dahu")
      @job=@cluster.submit_job({:command => "sleep 300", :stdout => "/dev/null", :stderr => "/dev/null"},"kameleon")
    end
    it "should return an id" do
      @job["id"].should be_an(Integer)
    end
    it "should have created a job" do
      @cluster.get_job(@job["id"],"kameleon")["id"].should == @job["id"]
    end
    it "should have the job listed in the jobs collection" do
      @cluster.get_jobs.index{|job| job["id"]=@job["id"] }.should_not be nil
    end
    it "should be able to ask for the job to be deleted" do
      @cluster.delete_job(@job["id"],"kameleon").should be_true
    end
  end # Job submission
end # cigri-clusterlib
