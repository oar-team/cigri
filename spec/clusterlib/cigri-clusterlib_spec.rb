require 'cigri-clusterlib'
require 'dbi'
require 'spec_helper'

describe 'cigri-clusterlib' do
  before(:all) do
    @old_LOGGER=LOGGER
    LOGGER = Cigri::Logger.new('clusterlib tests', "STDOUT")
  end
  after(:all) do
    LOGGER=@old_LOGGER
  end
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
    it 'should return a Resfully Collection' do
      @cluster.get_resources.should be_a(Restfully::Collection)
    end
  end # Resources check
end # cigri-clusterlib
