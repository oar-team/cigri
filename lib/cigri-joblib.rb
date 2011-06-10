#!/usr/bin/ruby -w
#
# This library contains the classes relative to Jobs
#

require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-iolib'

CONF=Cigri.conf unless defined? CONF
JOBLIBLOGGER = Cigri::Logger.new('JOBLIB', CONF.get('LOG_FILE'))

module Cigri

  # Job class
  # A Job instance can be get from the database or newly created
  # See Datarecord class for more doc
  class Job < Datarecord
    attr_reader :props

    # Creates a new job or get it from the database
    def initialize(props={})
      super("jobs",props)
    end

  end # class Job

  # Jobset class
  # Example: 
  #  jobs=Cigri::Jobset.new(:where => "name like 'obiwan%'")
  #  jobs=Cigri::Jobset.new
  #  jobs.get_running
  class Jobset < Dataset

    # Creates the new jobset
    def initialize(props={})
      super("jobs",props)
    end

    # Alias to the dataset records
    def jobs
      @records
    end

    # Fill the jobset with the currently running jobs
    def get_running
      fill(get("jobs","*","state = 'running'"))
    end
 
  end # Class Jobset


  # Job to launch class
  # A Job to launch instance can be get from the database or newly created
  # See Datarecord class for more doc
  class Jobtolaunch < Datarecord
    attr_reader :props

    # Creates a new job to launch entry or get it from the database
    def initialize(props={})
      super("jobs_to_launch",props)
    end

  end # class Jobtolaunch

  # Campaign class
  # A Campaign instance can be get from the database or newly created
  # See Datarecord class for more doc
  class Campaign < Datarecord
    attr_reader :props, :clusters

    # Creates a new campaign entry or get it from the database
    def initialize(props={})
      super("campaign",props)
      @clusters={}
    end

    # Fills the @cluster hash with the properties (JDL) of this campaign
    # This hash looks like:
    #  {1=>
    #    [{"resources"=>"core=1"},
    #     {"exec_file"=>"$HOME/cigri-3/tmp/test1.sh"}],
    #   3=>
    #    [{"resources"=>"core=1"},
    #     {"exec_file"=>"$HOME/cigri-3/tmp/test1.sh"}]}
    #
    def get_clusters
      get_campaign_properties(@dbh,id).each do |row|
        cluster_id=row["cluster_id"]
        @clusters[cluster_id]={} if @clusters[cluster_id].nil?
        @clusters[cluster_id][row["name"]]=row["value"]
      end
    end

    # Return false if the campaign has no more tasks to run
    # Else, returns the number of tasks remaining
    def have_remaining_tasks?
      count=get_campaign_remaining_tasks_number(@dbh,id)
      return count if count != 0
    end

    # Return false if campaign has no active clusters
    def have_active_clusters?
      have=0
      @clusters.each do |cluster|
        #TODO: should check for blacklisted clusters (colombo)
        have += 1
      end
      return have if have != 0
    end

  end # class Campaign

  # Campaignset class
  # Example: 
  #  campaigns=Cigri::Campaigns.new
  #  campaigns.get_running
  class Campaignset < Dataset

    # Creates the new campaignset
    def initialize(props={})
      super("campaigns",props)
      to_campaigns
    end

    # Alias to the dataset records
    def campaigns
      @records
    end

    # Convert the datarecords objects to campaign objects
    # couldn't find someting similar to "extend Module"...
    def to_campaigns
      campaigns=[]
      @records.each do |record|
        props=record.props
        props[:nodb]=true
        campaigns << Campaign.new(props)
      end
      @records = campaigns
    end

    # Fill the campaignset with the currently running campaigns
    def get_running
      fill(get("campaigns","*","state = 'in_treatment'"))
      to_campaigns
    end
 
  end # Class Campaignset





end # module Cigri
