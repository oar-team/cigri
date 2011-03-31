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
    #   - level: level of verbosity (FATAL, ERROR, WARN, INFO, DEBUG)
    #   - logdev: location of the file to save the log (can be a stream as well)
    #   - shift_age: number of logfiles to keep
    #   - shift_size: maximum size of a logfile
    ##
    def initialize(progname, logdev, level = Cigri::Logger::INFO, shift_age = nil, shift_size = nil)
      config = Cigri::Conf.new
      shift_age = config.get('LOG_SHIFT_AGE') if (not shift_age) and config.exists?('LOG_SHIFT_AGE')
      shift_size = config.get('LOG_SHIFT_SIZE') if (not shift_size) and config.exists?('LOG_SHIFT_SIZE')
      level = config.get('LOG_LEVEL') if (not level) and config.exists?('LOG_LEVEL')
      super(logdev, shift_age, shift_size)
      self.level = level
      self.progname = progname
      self.formatter = proc { |severity, datetime, progname, msg|
        date = datetime.strftime('%Y-%m-%d %H:%M:%S.') << "%d" % datetime.usec
        "[%5s] [#{date}] [#{progname}] #{msg}\n" % severity
      }
    end
  end
end
