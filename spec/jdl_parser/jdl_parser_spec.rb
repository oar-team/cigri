require 'modules/jdl_parser/cigri_jdl_parser'
require 'cigri'

describe 'jdl_parser' do

  describe 'successes with minimal campaigns' do
    it 'should success with the cluster options used' do
      lambda{Cigri::JDLParser.parse('{"name":"n", "nb_jobs":0,"clusters":{"c":{"exec_file":"e"}}}')}.should_not raise_error
    end
    
    it 'should success with the global options used' do
      lambda{Cigri::JDLParser.parse('{"name":"n", "nb_jobs":0,"exec_file":"e","clusters":{"c":{}}}')}.should_not raise_error
    end
  end # successes with minimal campaigns
  
  describe 'missing parameters' do
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
  end
end # jdl_parser
