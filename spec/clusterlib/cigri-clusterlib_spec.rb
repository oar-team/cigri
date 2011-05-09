require 'cigri-clusterlib'
require 'dbi'
require 'spec_helper'

describe 'cigri-clusterlib' do
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
      @cluster=Cigri::Cluster.new(:name => "fukushima")
    end
    it 'should return an array' do
      @cluster.get_resources.should be_an(Array)
    end
  end # Resources check
end # cigri-clusterlib
