require 'spec_helper'
require 'cigri-restclientlib'
require 'cigri-clusterlib'
require 'cigri-colombolib'
require 'rdbi'
require 'json'
require 'yaml'

Test::Unit::AutoRunner.need_auto_run = false if defined?(Test::Unit::AutoRunner)

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
                                    "api_auth_type" => "cert"},
                                       "application/json")
    end
    it 'should return an array' do
      @rest.get_collection("resources").should be_an(Array)
    end
    it 'should manage paginated collection' do
      @rest.get_collection("resources?limit=100").length.should > 100
    end
 end

end

describe 'cigri-clusterlib (Cluster)' do
  describe "Initialize" do
    it 'should not succeed when no arg given' do
      lambda{Cigri::Cluster.new()}.should raise_error Exception
    end
    it 'should not succeed when an invalid cluster name is given' do
      lambda{Cigri::Cluster.new(:name => "non_existent.cluster",:api_auth_type => "cert")}.should raise_error Exception
    end
    it 'should succeed when the name of a valid cluster is given' do
      lambda{Cigri::Cluster.new(:name => "dahu")}.should_not raise_error Exception
    end
    it 'should succeed when the id of a valid cluster is given' do
      lambda{Cigri::Cluster.new(:id => 2)}.should_not raise_error Exception
    end
  end # Initialize

  describe "Dahu resources" do
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
      @job=@cluster.submit_job({:command => "sleep 300", :stdout => "/dev/null", :stderr => "/dev/null", :project => "test"},"bzizou")
    end
    it "should return an id" do
      @job["id"].should be_an(Integer)
    end
    it "should have created a job" do
      @cluster.get_job(@job["id"],"bzizou")["id"].should == @job["id"]
    end
    it "should have the job listed in the jobs collection" do
      @cluster.get_jobs.index{|job| job["id"]=@job["id"] }.should_not be nil
    end
    it "should be able to ask for the job to be deleted" do
      @cluster.delete_job(@job["id"],"bzizou")["status"].should equal? "Delete request registered"
    end
  end # Job submission

  describe "Job submission (OAR3)" do
    before(:all) do
      @cluster=Cigri::Cluster.new(:name => "dahu-oar3")
      @job=@cluster.submit_job({:command => "sleep 300", :stdout => "/dev/null", :stderr => "/dev/null", :project => "test", :type => ["devel"], :resource => ["/cpu=1,walltime=0:10:0"]},"bzizou")
    end
    it "should return an id" do
      @job["id"].should be_an(Integer)
    end
    it "should have created a job" do
      @cluster.get_job(@job["id"],"bzizou")["id"].should == @job["id"]
    end
    it "should have the job listed in the jobs collection" do
      @cluster.get_jobs.index{|job| job["id"]=@job["id"] }.should_not be nil
    end
    it "should be able to ask for the job to be deleted" do
      @cluster.delete_job(@job["id"],"bzizou")["status"].should equal? "Delete request registered"
    end
  end # Job submission

end # cigri-clusterlib

describe 'cigri-clusterlib (ClusterSet)' do
  describe "Initialize" do
    it 'should return an array' do
      Cigri::ClusterSet.new().should be_a Array
    end
    it 'should return Clusters' do
      Cigri::ClusterSet.new()[0].description["name"].should be_a String
    end
    it 'should return only one element when the id of a cluster is given' do
      Cigri::ClusterSet.new("id=8").length.should == 1
    end
  end # Initialize
end # cigri-clusterlib
