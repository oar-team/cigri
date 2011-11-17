module Cigri
  ##
  # Cigri Exceptions are just normal exceptions that are logger if 
  # LOGGER exists
  ##
  class Exception < StandardError
    def initialize(msg, logger = nil)
      if logger and logger.class == Cigri::Logger
        logger.error('Exception raised: ' + msg)
      end
      super(msg)
    end
  end
end
