require 'spec_helper'
require 'cigri-conflib'

describe 'cigri-conflib' do

  describe 'initialize failures' do
    it 'should fail when a non-existant file is given' do
      lambda{Cigri::Conf.new("/tmp/qsdfghjklm.conf")}.should raise_error Cigri::Error
    end
  end # initialize failures
  
  describe 'initialize successes' do    
    it 'should success when an existent file is given' do
      lambda{Cigri::Conf.new('etc/cigri.conf')}.should_not raise_error Exception
    end
  end # initialize successes

  describe 'methods' do
    before(:each) do
      @config = Cigri::Conf.new('etc/cigri.conf')
    end
    it 'should say if a variable is non-existent' do
      @config.exists?("Obiwankenobi").should be_false
    end
    it 'should say if a variable exists' do
      @config.exists?("INSTALL_PATH").should be_true
    end
    it 'should return a value for INSTALL_PATH' do
      @config.get("INSTALL_PATH").should be_a(String)
    end
    it 'should scan the config file and return the number of variables' do
      @config.scan.should > 0
    end
    
    it 'should raise an excetion when getting an unexisting key' do
      lambda{@config.get('fbuisghsdui')}.should raise_error Cigri::Error
    end
  end # end methods
  
  describe 'unique cigri conf' do
    it 'should return a conf type' do
      Cigri.conf.should be_a(Cigri::Conf)
    end
    it 'should only return one object' do
      Cigri.conf.should == Cigri.conf
    end
  end
  
end # cigri-conflib
