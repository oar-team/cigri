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
  class TokenNotFound < Error; end
  ##
  # Raised for a 400 api rest-server error
  ##
  class ClusterAPIBadRequest < Error; end
  ##
  # Raised for a 401 api rest-server error
  ##
  class ClusterAPIPermissionDenied < Error; end
  ##
  # Raised for a 403 api rest-server error
  ##
  class ClusterAPIForbidden < Error; end
  ##
  # Raised for a 500 api rest-server error
  ##
  class ClusterAPIServerError < Error; end
  ##
  # Raised for a connection error to a cluster api rest-server 
  ##
  class ClusterAPIConnectionError < Error; end
  ##
  # Raised for an admission_rule error
  ##
  class AdmissionRuleError < Error; end
  ##
  # Raised when a cluster API does not find a resource
  ##
  class ClusterAPINotFound < Error; end
  ##
  # Raised when a cluster API timeouts
  ##
  class ClusterAPITimeout < Error; end
  ##
  # Raised when a cluster API timeouts at a POST query
  ##
  class ClusterAPITimeoutPOST < Error; end
  ##
  # Raised when a POST request is too large
  ##
  class ClusterAPITooLarge < Error; end
 
    
end
