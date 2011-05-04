module Cigri
  ##
  # Cigri Exceptions are just normal exceptions that are logger if 
  # LOGGER exists
  ##
  class Exception < Exception
    def initialize(msg)
      if defined? LOGGER and LOGGER.class == Cigri::Logger
        LOGGER.error('Exception raised: ' + msg)
      end
      super
    end
  end
end
