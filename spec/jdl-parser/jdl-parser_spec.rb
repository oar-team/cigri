require 'cigri'
require 'modules/jdl-parser/jdl-parser'
require 'spec_helper'

describe 'jdl-parser' do

  describe 'successes with minimal campaigns' do
    it 'should success with the cluster options used' do
      lambda{Cigri::JDLParser.parse('{"name":"n", "nb_jobs":0,"clusters":{"c":{"exec_file":"e"}}}')}.should_not raise_error
    end
    it 'should success with the global options used' do
      lambda{Cigri::JDLParser.parse('{"name":"n", "nb_jobs":0,"exec_file":"e","clusters":{"c":{}}}')}.should_not raise_error
    end
    it 'should success with the global options used' do
      lambda{Cigri::JDLParser.parse('{"name":"n", "jobs_type":"desktop_computing","exec_file":"e","clusters":{"c":{}}}')}.should_not raise_error
    end
  end # successes with minimal campaigns
  
  describe 'missing fields' do
    it 'should fail if name missing' do
      lambda{Cigri::JDLParser.parse('{"nb_jobs":0,"clusters":{"c":{"exec_file":"e"}}}')}.should raise_error Cigri::Exception
    end
    it 'should fail if clusters missing' do
      lambda{Cigri::JDLParser.parse('{"name":"n", "nb_jobs":0}')}.should raise_error Cigri::Exception
    end
    it 'should fail if exec_file missing' do
      lambda{Cigri::JDLParser.parse('{"name":"n", "nb_jobs":0, "clusters":{"c":{}}}')}.should raise_error Cigri::Exception
    end
    it 'should fail if no cluster defined' do
      lambda{Cigri::JDLParser.parse('{"name":"n", "nb_jobs":0, "clusters":{}}')}.should raise_error Cigri::Exception
    end
  end # missing parameters
  
  describe 'parameters file' do
    it 'should success if param_file given' do
      lambda{Cigri::JDLParser.parse('{"name":"n","param_file":"p","clusters":{"c":{"exec_file":"e"}}}')}.should_not raise_error
    end
    it 'should success if nb_jobs given' do
      lambda{Cigri::JDLParser.parse('{"name":"n","nb_jobs":0,"clusters":{"c":{"exec_file":"e"}}}')}.should_not raise_error
    end
    it 'should success if jobs_type is desktop_computing given' do
      lambda{Cigri::JDLParser.parse('{"name":"n","jobs_type":"desktop_computing","clusters":{"c":{"exec_file":"e"}}}')}.should_not raise_error
    end
    it 'should fail if no param_file or nb_jobs or jobs_type=desktop_computing given' do
      lambda{Cigri::JDLParser.parse('{"name":"n","clusters":{"c":{"exec_file":"e"}}}')}.should raise_error Cigri::Exception
    end
  end # parameters file
  
end # jdl_parser
