require 'cigri-restclientlib'
require 'cigri-clusterlib'
require 'dbi'
require 'spec_helper'
require 'json'
require 'yaml'

describe 'cigri-restclientlib (RestAPI)' do
  describe "Initialize" do
    it 'should not raise error' do
      lambda{Cigri::RestAPI.new("http://localhost/oarapi","","","application/json")}.should_not raise_error Exception
    end
    it 'should have a root ok in JSON' do
      rest=Cigri::RestAPI.new("http://localhost/oarapi","","","application/json")
      lambda{rest.get("")}.should_not raise_error Exception
    end
    it 'should have a root ok in YAML' do
      rest=Cigri::RestAPI.new("http://localhost/oarapi","","","text/yaml")
      lambda{rest.get("")}.should_not raise_error Exception
    end
  end
  describe "Resources" do
    before(:all) do
      @rest=Cigri::RestAPI.new("http://localhost/oarapi","","","application/json")
    end
    it 'should return a hash' do
      @rest.get("resources").should be_an(Hash)
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
      lambda{Cigri::Cluster.new(:name => "tchernobyl")}.should_not raise_error Exception
    end
    it 'should succeed when the id of a valid cluster is given' do
      lambda{Cigri::Cluster.new(:id => 2)}.should_not raise_error Exception
    end
  end # Initialize

  describe "Tchernobyl resources" do
    before(:all) do
      @cluster=Cigri::Cluster.new(:name => "tchernobyl")
    end
    it 'should return an array' do
      @cluster.get_resources.should be_an(Array)
    end
  end # Resources check
  
  describe "Job submission" do
    before(:all) do
      @cluster=Cigri::Cluster.new(:name => "tchernobyl")
      @job=@cluster.submit_job(:command => "sleep 300")
    end
    it "should return an id" do
      @job["id"].should be_an(Integer)
    end
    it "should have created a job" do
      @cluster.get_job(@job["id"])["id"].should == @job["id"]
    end
    it "should be able to ask for the job to be deleted" do
      @cluster.delete_job(@job["id"]).should be_true
    end
  end # Job submission
end # cigri-clusterlib
