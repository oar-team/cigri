module Cigri
  ##
  # Cigri Exceptions are just normal exceptions that are logged if 
  # a logger is given as argument
  ##
  class Error < StandardError
    def initialize(msg, logger = nil)
      if logger and logger.class == Cigri::Logger
        logger.error('Exception raised: ' + msg)
      end
      super(msg)
    end
  end

  class NotFound < Error; end
  class ParseError < Error; end
  class Unauthorized < Error; end
  class PermissionDenied < Error; end
end
