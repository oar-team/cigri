require 'json'
require 'pp'

# Mandatory attributes in the JDL
MANDATORY_CLUSTER = %w{exec_file}
MANDATORY_GLOBAL = %w{name clusters}

#Attributes that contain a path
PATH_ATTRIBUTES = %w{exec_file param_file}

module Cigri
  
  class JDLParser
    
    def self.parse(str) 
      json = JSON.parse(str)
      res = {}
      
      #Rename keys in lowercase to avoid errors just based on case
      json.each { |k, v| res[k.downcase] = v }
      
      #check if all mandatory parameters are defined
      MANDATORY_GLOBAL.each do |field|
        raise "JDL file does not contain mandatory field #{field}." unless res[field]
      end
      MANDATORY_CLUSTER.each do |field|
        res['clusters'].each do |cluster|
          raise "Cluster #{cluster[0]} does not have mandatory field \"#{field}\"" unless cluster[1][field] or res[field]
        end
      end
      
      #Expends all the paths
      self.correct_path!(res)
      
      return res;
    end
    
    # Expands the paths
    def self.correct_path!(hash)
      PATH_ATTRIBUTES.each do |attribute|
        hash[attribute] = File.expand_path(hash[attribute].sub!('$HOME', '~')) if hash[attribute]
        hash['clusters'].each_value do |cluster|
          cluster[attribute] = File.expand_path(cluster[attribute].sub!('$HOME', '~')) if cluster[attribute]
        end
      end
    end
    
  end # class JDLParser
end
