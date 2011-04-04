require 'cigri-logger'

describe 'cigri-logger' do
  file = '/tmp/rspec-cigri.log'
  logger = nil

  def log(logger)
    logger.debug('some debug information')
    logger.info('some info')
    logger.warn('warn, something may have gone wrong')
    logger.error('error, something went wrong')
    logger.fatal('fatal, armagueddon is coming')
  end

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
      lambda{Cigri::Logger.new('spec', '/dev/null')}.should_not raise_error Exception
    end
    it 'should success when many args given' do
      lambda{Cigri::Logger.new('spec', '/dev/null', Cigri::Logger::FATAL, 10, 10)}.should_not raise_error Exception
    end
  end # initialize successes
  
  describe 'different logging levels' do
    after(:each) do
      File.delete(file)
    end
    
    it 'should print only fatal' do
      logger = Cigri::Logger.new('spec', file, Cigri::Logger::FATAL)
      log(logger)
      File.readlines(file).length.should == 2
    end
    it 'should print errors' do
      logger = Cigri::Logger.new('spec', file, Cigri::Logger::ERROR)
      log(logger)
      File.readlines(file).length.should == 3
    end
    it 'should print warnings' do
      logger = Cigri::Logger.new('spec', file, Cigri::Logger::WARN)
      log(logger)
      File.readlines(file).length.should == 4
    end
    it 'should print info' do
      logger = Cigri::Logger.new('spec', file, Cigri::Logger::INFO)
      log(logger)
      File.readlines(file).length.should == 5
    end
    it 'should print everything' do
      logger = Cigri::Logger.new('spec', file, Cigri::Logger::DEBUG)
      log(logger)
      File.readlines(file).length.should == 6
    end
  end # different logging levels
  
  describe 'shift options' do
    it 'should generate 2 logfiles' do
      logger = Cigri::Logger.new('spec', file, Cigri::Logger::DEBUG, 2, 200)
      10.times{log(logger)}
      files = Dir.glob("#{file}*")
      files.length.should == 2
      files.each {|f| File.delete(f)}
    end
    it 'should be smaller than the given size' do
      logger = Cigri::Logger.new('spec', file, Cigri::Logger::DEBUG, 1, 256)
      log(logger) #log procuces a file of size 417
      File.size(file).should <= 256
      File.delete(file)
    end
    it 'should be smaller than the given size' do
      logger = Cigri::Logger.new('spec', file, Cigri::Logger::DEBUG, 1, 200)
      log(logger) #log procuces 6 lines
      File.readlines(file).length.should == 3
      File.delete(file)
    end
  end # shift options
end # cigri-logger
