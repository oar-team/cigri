require 'logger'
require 'cigri-conflib'

module Cigri
  ##
  # Specific Logger for Cigri. 
  # Changes the ruby logger output and needs a progname
  ##
  class Logger < Logger
    ##
    # Create a new Logger: logger = Logger.new('module', STDOUT [, shift_age, shift_size])
    # Params:
    #   - progname: Name of the module you want to log
    #   - logdev: location of the file to save the log (can be STDOUT or STDERR). Default = STDOUT
    ##
    def initialize(progname, logdev = 'STDOUT')
      config = Cigri::Conf.new
      level = config.get('LOG_LEVEL') if config.exists?('LOG_LEVEL')
      logdev = STDOUT if logdev.eql? 'STDOUT'
      logdev = STDERR if logdev.eql? 'STDERR'
      super(logdev)
      self.progname = progname
      self.level = Logger.const_get(level)
      self.formatter = proc { |severity, datetime, progname, msg|
        date = datetime.strftime('%Y-%m-%d %H:%M:%S.') << "%d" % datetime.usec
        "[%5s] [#{date}] [#{progname}] #{msg}\n" % severity
      }
    end
  end
end
