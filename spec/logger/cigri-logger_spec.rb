require 'cigri-logger'

describe 'cigri-logger' do

  describe 'initialize failures' do
    it 'should fail when no arg given' do
      lambda{Cigri::Logger.new()}.should raise_error Exception
    end
    it 'should fail when 1 arg given' do
      lambda{Cigri::Logger.new('spec')}.should raise_error Exception
    end
    it 'should fail when 2 args given and second arg not stream or writable file' do
      lambda{Cigri::Logger.new('spec', '/detzkfuidhb/hfgsdh')}.should raise_error Exception
    end
  end # initialize failures
  
  describe 'initialize successes' do    
    it 'should success when 2 args given' do
      lambda{Cigri::Logger.new('spec', STDOUT)}.should_not raise_error Exception
    end
    it 'should success when many args given' do
      lambda{Cigri::Logger.new('spec', STDOUT, 'toto', 123)}.should_not raise_error Exception
    end
  end # initialize successes
  
end # cigri-logger
