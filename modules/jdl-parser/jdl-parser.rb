require 'json'
require 'cigri'

# Mandatory attributes in the JDL
MANDATORY_CLUSTER = %w{exec_file}
MANDATORY_GLOBAL = %w{name clusters}

module Cigri
  ##
  # Class defined to handle the submission of the JDL file in cigri.
  ##
  class JDLParser
    
    ##
    # Parses the json string given as parameter.
    # 
    # == Parameters:
    # str:: string to parse
    # 
    # == Returns:
    # Objects corresponding to the json string
    # == Exceptions:
    # cigri::exception if the JDL is not well formed
    ##
    def self.parse(str) 
      json = JSON.parse(str)
      res = {}
      
      #Rename keys in lowercase to avoid errors just based on case
      json.each { |k, v| res[k.downcase] = v }
      
      #check if all mandatory parameters are defined
      MANDATORY_GLOBAL.each do |field|
        unless res[field]
          raise Cigri::Exception, "JDL file does not contain mandatory field #{field}."
        end
      end
      MANDATORY_CLUSTER.each do |field|
        res['clusters'].each do |cluster|
          unless cluster[1][field] or res[field]
            raise Cigri::Exception, "Cluster #{cluster[0]} does not have mandatory field \"#{field}\"" 
          end
        end
      end
      
      #Verify there is at least one cluster
      if res['clusters'].length == 0
        raise Cigri::Exception, 'You must define at least one cluster in the "clusters" field'
      end
      
      #verify there are parameters for the campaign
      unless res['param_file'] or res['nb_jobs'] or 
             (res['jobs_type'] and res['jobs_type'].downcase.eql?('desktop_computing'))
        raise Cigri::Exception, 'No parameters for your campaign are defined.' +
        'You must define param_file or nb_jobs or ' +
        'have "jobs_type": "desktop_computing"'
      end
      
      return res;
    end # def self.parse
    
    ##
    # Saves the JSON in the database given in parameter
    ##
    def self.save(dbh, json)
      logger = Cigri::Logger.new('JDL Parser', STDOUT)
      logger.debug("Saving JDL")
      begin
        res = self.parse(json)
      rescue Cigri::Exception => e
        logger.error("JDL file not well defined: #{json}")
        raise Cigri::Exception, 'JDL badly defined, not saving in the database'
      end
      logger.debug("JDL file is well defined")
      cigri_submit(dbh, res)
      logger.info("Campaign saved in database")
    end # def self.save
  end # class JDLParser
end
