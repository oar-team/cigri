require 'logger'

module Cigri
  ##
  # Create a new CigriLogger: logger = CigriLogger.new(STDOUT)
  # Define the module: logger.progname = 'module'
  # log something: logger.info("info")
  ##
  class CigriLogger < Logger
    def initialize(*args)
      super(*args)
      self.formatter = proc { |severity, datetime, progname, msg|
        date = datetime.strftime('%Y-%m-%d %H:%M:%S.') << "%d" % datetime.usec
        "[%5s] [#{date}] [#{progname}] #{msg}\n" % severity
      }
    end
  end
end
