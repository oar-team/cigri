require 'cigri'
require 'json'
require 'pp'
require 'etc'

module Cigri
  ##
  # Class defined to handle the submission of the JDL file in cigri.
  ##
  class JDLParser
    
    # Mandatory attributes in the clusters field of the JDL
    MANDATORY_CLUSTER = %w{exec_file}
    # Mandatory attributes in the campaign of the JDl
    MANDATORY_GLOBAL  = %w{name clusters}
    # All the fields that can be used in a campaign description
    ALL_GLOBAL        = MANDATORY_GLOBAL + %w{param_file nb_jobs jobs_type params}
    
    ##
    # Parses the json string given as parameter.
    # 
    # == Parameters:
    # str:: string to parse
    # 
    # == Returns:
    # Objects corresponding to the json string
    #
    # == Exceptions:
    # Cigri::Error if the JDL is not well formed
    ##
    def self.parse(str) 
      json = JSON.parse(str)
      res = {}
      
      #Rename keys in lowercase to avoid errors just based on case
      json.each { |k, v| res[k.downcase] = v }
      
      #check if all mandatory parameters are defined
      MANDATORY_GLOBAL.each do |field|
        unless res[field]
          raise Cigri::ParseError, "JDL file does not contain mandatory field '#{field}'"
        end
      end
      MANDATORY_CLUSTER.each do |field|
        res['clusters'].each_value do |cluster|
          unless cluster[field] or res[field]
            raise Cigri::ParseError, "Cluster #{cluster} does not have mandatory field '#{field}'" 
          end
        end
      end
      
      #Verify there is at least one cluster
      if res['clusters'].length == 0
        raise Cigri::ParseError, 'You must define at least one cluster in the "clusters" field'
      end
      
      #verify there are parameters for the campaign
      unless res['param_file'] or res['nb_jobs'] or res['params'] or
             (res['jobs_type'] and res['jobs_type'].downcase.eql?('desktop_computing'))
        raise Cigri::ParseError, 'No parameters for your campaign are defined.' +
        'You must define param_file or nb_jobs or ' +
        'have "jobs_type": "desktop_computing"'
      end
      
      return res;
    end # def self.parse
    
    ##
    # Saves the JSON in the database given in parameter
    #
    # == Parameters:
    # dbh:: handle to a database
    # json:: string to parse
    # user:: username of the submitter
    # 
    # == Returns:
    # Campaign id if correctly created, nil if not
    #
    # == Exceptions:
    # Cigri::Error if the JDL is not well formed
    # Exception if there was an error when saving in the database
    ##
    def self.save(dbh, json, user)
      config = Cigri.conf
      logger = Cigri::Logger.new('JDL Parser', config.get('LOG_FILE'))
      logger.debug("Saving JDL")
      begin
        res = self.parse(json)
      rescue JSON::ParserError => e
        logger.error("JDL file not well defined: #{json}")
        raise Cigri::ParseError, "JDL badly defined: #{e.inspect}"
      end
      
      default_values!(res, config)
      expand_jdl!(res)
      expand_macros!(res,user)
      set_params!(res)
      
      logger.debug('JDL file is well defined')
      
      # Submit the campaign
      begin
        campaign_id=cigri_submit(dbh, res, user)
        logger.info('Campaign saved in database')
        return campaign_id
      rescue Exception => e
        logger.error('Campaign could not be saved in DB:' + e.message + e.backtrace)
        raise e
      end
    end # def self.save
    
    ##
    # Expands the JDL: if options are defined for every cluster, copy them in the cluster
    #
    # == Parameters
    # - jdl represented as a json bject (hash + array)
    ##
    def self.expand_jdl!(jdl)
      raise Cigri::ParseError, 'JDL does not contain the "clusters" field' unless jdl['clusters']
      jdl.each do |key, val|
        unless ALL_GLOBAL.include?(key)
          jdl['clusters'].each_value do |cluster|
            cluster[key] = val unless cluster[key]
          end
         jdl.delete(key)
        end
      end
    end # def self.expand_jdl!
    
    ##
    # Fills the params attribute if needed (not when desktop_computing)
    #
    # == Parameters
    # - jdl represented as objects (hash + arrays)
    ##
    def self.set_params!(jdl)
      return if (jdl['jobs_type'] and jdl['jobs_type'].downcase.eql?('desktop_computing'))

      if jdl['nb_jobs']
        params = (0...jdl['nb_jobs']).to_a.collect{|a| a.to_s}
        jdl.delete('nb_jobs')
      elsif jdl['param_file']
        #catch all environment variables and replace them
        jdl['param_file'].scan(/\$\w*/).each do |match|
          jdl['param_file'][match] = ENV[match.delete('$')]
        end
        jdl['param_file'] = File.expand_path(jdl['param_file'])
        raise Cigri::ParseError, "Parameter file '#{jdl['param_file']}' is not readable" unless File.readable?(jdl['param_file'])
        params = File.readlines(jdl['param_file']).map!{|a| a.strip}
        jdl.delete('param_file')
      end
      jdl['params'] = params unless jdl['params']
    end # def self.get_params!

    private
    
    # Default global fixed values
    DEFAULT_VALUES_GLOBAL = {'jobs_type' => 'normal'}
    # Fixed defauls values
    DEFAULT_VALUES = {'type'                    => 'best-effort',
                      'exec_directory'          => '$HOME',
                      'output_gathering_method' => 'None',
                      'dimensional_grouping'    => 'false',
                      'temporal_grouping'       => 'false',
                      'checkpointing_type'      => 'None',
                      'test_mode'               => 'false',
                      'properties'              => '',
                      'project'                 => ''}
    # Default values defined by configuration file
    DEFAULT_VALUES_CONF = {'walltime'  => 'DEFAULT_JOB_WALLTIME', 
                           'resources' => 'DEFAULT_JOB_RESOURCES'}
    # Default global values defined by configuration file
    DEFAULT_VALUES_GLOBAL_CONF = {}
    
    # Set default values
    def self.default_values!(jdl, config)
      raise Cigri::ParseError, 'JDL does not contain the "clusters" field' unless jdl['clusters']
      
      #set default values for global attributes
      DEFAULT_VALUES_GLOBAL.each do |key, val|
        jdl[key] = val unless jdl[key]
      end
      DEFAULT_VALUES_GLOBAL_CONF.each do |key, val|
        raise Cigri::NotFound, "Mandatory option '#{val}'' not found in configuration file" unless config.exists?(val)
        jdl[key] = config.get(val) unless jdl[key]
      end
      
      # set default values for clusters attributes
      jdl['clusters'].each_value do |cluster|
        DEFAULT_VALUES.each do |key, val|
          cluster[key] = val unless jdl[key] or cluster[key]
        end
        DEFAULT_VALUES_CONF.each do |key, val|
          raise Cigri::NotFound, "Mandatory option '#{val}' not found in configuration file" unless config.exists?(val)
          cluster[key] = config.get(val) unless jdl[key] or cluster[key]
        end
      end
    end # default_values!

    # Expand the macros
    # {HOME} or ~: replaced by $HOME
    # {CAMPAIGN_ID}: replaced by $CIGRI_CAMPAIGN_ID
    # {OAR_JOB_ID}: replaced by $OAR_JOB_ID
    def self.expand_macros!(jdl,user)
      # global parameters
      if jdl['param_file']
          jdl['param_file'].gsub!(/~/,Etc.getpwnam(user).dir)
          jdl['param_file'].gsub!(/{HOME}/,Etc.getpwnam(user).dir)
      end
      # clusters parameters
      jdl['clusters'].each_value do |cluster|
        cluster.each do |key,val|
          # Macros for exec_directory and exec_file
          if key == "exec_directory" or key == "exec_file"
            # '~' or {HOME}replacement
            cluster[key].gsub!(/~/,"$HOME")
            cluster[key].gsub!(/{HOME}/,"$HOME")
            # {CAMPAIGN_ID} replacement (only for exec_file)
            cluster[key].gsub!(/{CAMPAIGN_ID}/,"\\$CIGRI_CAMPAIGN_ID") if key == "exec_file"
          end
          # Macros for prologue and epilogue
          if key == "prologue" or key == "epilogue"
            cluster[key].map!{|s| s.gsub(/{CAMPAIGN_ID}/,"\\$CIGRI_CAMPAIGN_ID")}
            cluster[key].map!{|s| s.gsub(/{OAR_JOB_ID}/,"\\$OAR_JOB_ID")}
            cluster[key].map!{|s| s.gsub(/~/,"\\$HOME")}
            cluster[key].map!{|s| s.gsub(/{HOME}/,"\\$HOME")}
          end
        end
      end 
    end # expand_macros
  end # class JDLParser
end
