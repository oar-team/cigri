#require 'spec_helper'
require 'cigri'
require 'jdl-parser'

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
      lambda{Cigri::JDLParser.parse('{"nb_jobs":0,"clusters":{"c":{"exec_file":"e"}}}')}.should raise_error Cigri::ParseError
    end
    it 'should fail if clusters missing' do
      lambda{Cigri::JDLParser.parse('{"name":"n", "nb_jobs":0}')}.should raise_error Cigri::ParseError
    end
    it 'should fail if exec_file missing' do
      lambda{Cigri::JDLParser.parse('{"name":"n", "nb_jobs":0, "clusters":{"c":{}}}')}.should raise_error Cigri::ParseError
    end
    it 'should fail if no cluster defined' do
      lambda{Cigri::JDLParser.parse('{"name":"n", "nb_jobs":0, "clusters":{}}')}.should raise_error Cigri::ParseError
    end
  end # missing parameters
  
  describe 'parameters file' do
    it 'should success if param_file given' do
      lambda{Cigri::JDLParser.parse('{"name":"n","param_file":"p","clusters":{"c":{"exec_file":"e"}}}')}.should_not raise_error
    end
    it 'should success if params given' do
      lambda{Cigri::JDLParser.parse('{"name":"n","params":["p1", "p2"],"clusters":{"c":{"exec_file":"e"}}}')}.should_not raise_error
    end
    it 'should success if nb_jobs given' do
      lambda{Cigri::JDLParser.parse('{"name":"n","nb_jobs":0,"clusters":{"c":{"exec_file":"e"}}}')}.should_not raise_error
    end
    it 'should success if jobs_type is desktop_computing given' do
      lambda{Cigri::JDLParser.parse('{"name":"n","jobs_type":"desktop_computing","clusters":{"c":{"exec_file":"e"}}}')}.should_not raise_error
    end
    it 'should fail if no param_file or nb_jobs or jobs_type=desktop_computing given' do
      lambda{Cigri::JDLParser.parse('{"name":"n","clusters":{"c":{"exec_file":"e"}}}')}.should raise_error Cigri::ParseError
    end
  end # parameters file
  
  describe 'expanding JDL' do
    it 'should expand global options' do
       a = Cigri::JDLParser.expand_jdl!(Cigri::JDLParser.parse('{"name":"n","nb_jobs":10,"exec_file":"e","clusters":{"c":{}}}'))
       b = Cigri::JDLParser.parse('{"name":"n","nb_jobs":10,"clusters":{"c":{"exec_file":"e"}}}')
       a.should == b
    end
    it 'should expand global options unless the option is defined in cluster' do
       a = Cigri::JDLParser.expand_jdl!(Cigri::JDLParser.parse('{"name":"n","nb_jobs":10,"exec_file":"e","clusters":{"c":{"exec_file":"toto"}}}'))
       b = Cigri::JDLParser.parse('{"name":"n","nb_jobs":10,"clusters":{"c":{"exec_file":"toto"}}}')
       a.should == b
    end
  end
  
  describe 'set_params' do
    it 'should expand the params' do
      a = Cigri::JDLParser.parse('{"name":"n","params":["0","1","2","3","4","5","6","7","8","9"],"clusters":{"c":{"exec_file":"toto"}}}')
      b = Cigri::JDLParser.parse('{"name":"n","nb_jobs":10,"clusters":{"c":{"exec_file":"toto"}}}')
      Cigri::JDLParser::set_params!(b)
      a.should == b
    end
    it 'should read a file and expand the params' do
      filename = '/tmp/cigri_rspec_example_file'
      str = "param 1\n param 2    \n    param3"
      File.open(filename, 'w') {|f| f.write(str) }
      a = Cigri::JDLParser.parse('{"name":"n","params":["param 1","param 2","param3"],"clusters":{"c":{"exec_file":"toto"}}}')
      b = Cigri::JDLParser.parse('{"name":"n","param_file":"' + filename + '","clusters":{"c":{"exec_file":"toto"}}}')
      Cigri::JDLParser::set_params!(b)
      File.delete(filename)
      a.should == b
    end
    it 'should read a file using ~ and expand the params' do
      filename = '~/cigri_rspec_example_file'
      str = "param 1\n param 2    \n    param3"
      File.open(File.expand_path(filename), 'w') {|f| f.write(str) }
      a = Cigri::JDLParser.parse('{"name":"n","params":["param 1","param 2","param3"],"clusters":{"c":{"exec_file":"toto"}}}')
      b = Cigri::JDLParser.parse('{"name":"n","param_file":"' + filename + '","clusters":{"c":{"exec_file":"toto"}}}')
      Cigri::JDLParser::set_params!(b)
      File.delete(File.expand_path(filename))
      a.should == b
    end
    it 'should read a file using $HOME and expand the params' do
      filename = '/cigri_rspec_example_file'
      str = "param 1\n param 2    \n    param3"
      File.open(File.expand_path('~' + filename), 'w') {|f| f.write(str) }
      a = Cigri::JDLParser.parse('{"name":"n","params":["param 1","param 2","param3"],"clusters":{"c":{"exec_file":"toto"}}}')
      b = Cigri::JDLParser.parse('{"name":"n","param_file":"$HOME' + filename + '","clusters":{"c":{"exec_file":"toto"}}}')
      Cigri::JDLParser::set_params!(b)
      File.delete(File.expand_path('~' + filename))
      a.should == b
    end
  end
  
  describe 'save' do
    before :each do
      @cid = -1
    end
    
    after :each do
      db_connect() do |dbh|
        delete_campaign(dbh, 'testuser', @cid) if @cid != -1
      end
    end
    
    it 'should be able to save a correct json' do 
      db_connect() do |dbh|
        lambda{@cid = Cigri::JDLParser.save(dbh, '{"name":"n","nb_jobs":10,"clusters":{"dahu":{"exec_file":"e"}}}', 'testuser')}.should_not raise_error
      end
    end
    
    it 'should fail if dbh is bad' do
      lambda{Cigri::JDLParser.save({}, '{"name":"n","nb_jobs":10,"clusters":{"dahu":{"exec_file":"e"}}}', 'testuser')}.should raise_error TypeError
    end
    
    it 'should not be able to save an incorrect json' do
      db_connect() do |dbh|
        lambda{@cid = Cigri::JDLParser.save(dbh, '{"name":"n", "clusters":{"dahu":{"exec_file":"e"}}}', 'testuser')}.should raise_error Cigri::ParseError
      end
    end

    it 'should return an id' do
      db_connect() do |dbh|
        @cid = Cigri::JDLParser.save(dbh, '{"name":"n","nb_jobs":10,"clusters":{"dahu":{"exec_file":"e"}}}', 'testuser')
        @cid.should be_an(Integer)
      end
    end

  end # save
  
end # jdl_parser
