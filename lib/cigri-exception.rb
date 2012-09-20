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
  ##
  # Raised for a 401 api rest-server error
  ##
  class ClusterAPIPermissionDenied < Error; end
  ##
  # Raised for a 500 api rest-server error
  ##
  class ClusterAPIServerError < Error; end
  ##
  # Raised for a connection error to a cluster api rest-server 
  ##
  class ClusterAPIConnectionError < Error; end
end
