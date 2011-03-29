require 'logger'

module Cigri
  ##
  # Specific Logger for Cigri. 
  # Changes the ruby logger output and needs a progname
  ##
  class Logger < Logger
    ##
    # Create a new Logger: logger = Logger.new('module', STDOUT)
    ##
    def initialize(progname, *args)
      super(*args)
      self.progname = progname
      self.formatter = proc { |severity, datetime, progname, msg|
        date = datetime.strftime('%Y-%m-%d %H:%M:%S.') << "%d" % datetime.usec
        "[%5s] [#{date}] [#{progname}] #{msg}\n" % severity
      }
    end
  end
end
