require 'json'

# Mandatory attributes in the JDL
MANDATORY_CLUSTER = %w{exec_file}
MANDATORY_GLOBAL = %w{name clusters}

module Cigri
  
  class JDLParser
    
    def self.parse(str) 
      json = JSON.parse(str)
      res = {}
      
      #Rename keys in lowercase to avoid errors just based on case
      json.each { |k, v| res[k.downcase] = v }
      
      #check if all mandatory parameters are defined
      MANDATORY_GLOBAL.each do |field|
        unless res[field]
          raise "JDL file does not contain mandatory field #{field}."
        end
      end
      MANDATORY_CLUSTER.each do |field|
        res['clusters'].each do |cluster|
          unless cluster[1][field] or res[field]
            raise "Cluster #{cluster[0]} does not have mandatory field \"#{field}\"" 
          end
        end
      end
      
      #Verify there is at least one cluster
      if res['clusters'].length == 0
        raise 'You must define at least one cluster in the "clusters" field'
      end
      
      #verify there are parameters for the campaign
      unless res['param_file'] or res['nb_jobs'] or 
             (res['jobs_type'] and res['jobs_type'].downcase.eql?('desktop_computing'))
        raise 'No parameters for your campaign are defined.' +
        'You must define param_file or nb_jobs or ' +
        'have "jobs_type": "desktop_computing"'
      end
      
      return res;
    end # def self.parse
    
    #saves the JSON in the database
    def self.save(dbh, json)
      begin
        self.parse(json)
      rescue Exception => e
        puts e
        raise 'JSON badly defined, not saving in the database'
      end
      
    end # def self.save
  end # class JDLParser
end
