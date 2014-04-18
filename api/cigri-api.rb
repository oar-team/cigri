# -*- coding: utf-8 -*-
$KCODE = 'UTF8'

require 'json'
require 'sinatra/base'
require 'time'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
ENV['CIGRICONFDIR'] = File.expand_path('../../etc', __FILE__)
require 'cigri'
require 'cigri-iolib'
require 'cigri-clusterlib'
require 'cigri-joblib'
require 'cigri-eventlib'
require 'cigri-colombolib'
#require 'ruby-prof'
require 'jdl-parser'
require 'rack_debugger'

CLUSTER_NAMES = {}
clusters=Cigri::ClusterSet.new
clusters.each do |cluster|
   CLUSTER_NAMES[cluster.id]=cluster.name
end

logger=Cigri::Logger.new('API', Cigri.conf.get('LOG_FILE'))

CAMPAIGN_THROUGHPUT_WINDOW=Cigri.conf.get('CAMPAIGN_THROUGHPUT_WINDOW',"3600").to_i

class API < Sinatra::Base
  configure do
    use RackDebugger, Cigri::Logger.new('API', Cigri.conf.get('LOG_FILE')) # better print of the requests in the logfile
    enable :method_override # used to make magic with hidden fields such as _put or _delete
    set :username_variable, Cigri.conf.get('API_HEADER_USERNAME') || "HTTP_X_CIGRI_USER"
  end
  
  before do
    content_type :json
  end
  
  # List all links
  get '/' do
    response['Allow'] = 'GET'
    output = {
        :links => [
          {:rel => :self, :href => to_url('')},
          {:rel => :collection, :href => to_url('campaigns'), 'title' => :campaigns},
          {:rel => :collection, :href => to_url('clusters'), 'title' => :clusters}
        ]
      }
    status 200
    print(output)
  end
  
  # List all running campaigns (in_treatment or paused)
  get '/campaigns/?' do
    #RubyProf.start
    response['Allow'] = 'GET,POST'
    
    items = []
    campaigns=Cigri::Campaignset.new
    campaigns.get_unfinished
    campaigns.compute_finished_jobs
    campaigns.each do |campaign|
      items << format_campaign(campaign)
    end
    output = {
      :items => items,
      :total => items.length,
      :links => [
          {:rel => :self, :href => to_url('campaigns')},
          {:rel => :parent, :href => to_url('')}
        ]
    }

    #result = RubyProf.stop
    #printer = RubyProf::GraphHtmlPrinter.new(result)
    #printer.print(File.new("/tmp/cigri_api_prof.html",  "w"))

    status 200
    print(output)
  end

  # Details of a campaign
  get '/campaigns/:id/?' do |id|
    response['Allow'] = 'DELETE,GET,POST,PUT'
    output = get_formated_campaign(id,true)

    status 200
    print(output)
  end

  # Stats of a campaign
  get '/campaigns/:id/stats/?' do |id|
    response['Allow'] = 'GET'
    output = get_campaign_stats(id)

    status 200
    print(output)
  end

  # Details of an event
  get '/events/:id/?' do |id|
    response['Allow'] = 'DELETE,GET,POST,PUT'
    output = get_formated_event(id)

    status 200
    print(output)
  end

  # List global events (not specific to a campaign)
  get '/events/?' do
    response['Allow'] = 'DELETE,GET,POST,PUT'
    limit = params['limit'] || 100
    offset = params['offset'] || 0

    output = get_formated_global_events(limit, offset)

    status 200
    print(output)
  end

  # Get infos about a unitary job
  get '/jobs/:id' do |id|
    response['Allow'] = 'GET'
    output = get_formated_job(id)
    status 200
    print(output)
  end

  # Get the stdout file of a job
  get '/jobs/:id/stdout' do |id|
    response['Allow'] = 'GET'
    output = get_job_output(id,"stdout")
    status 200
    print(output)
  end

  # Get the stderr file of a job
  get '/jobs/:id/stderr' do |id|
    response['Allow'] = 'GET'
    output = get_job_output(id,"stderr")
    status 200
    print(output)
  end

  # Get the jdl as saved in the database
  get '/campaigns/:id/jdl/?' do |id|
    response['Allow'] = 'GET'

    campaign = get_campaign(id,true)

    status 200
    print(JSON.parse(campaign.props[:jdl]))
  end
  
  # List all jobs of a campaign
  get '/campaigns/:id/jobs/?' do |id|
    response['Allow'] = 'GET,POST'
    
    limit = params['limit'] || 100
    offset = params['offset'] || 0

    output = get_formated_jobs(id, limit, offset)

    status 200
    print(output)
  end
 
  # List all finished jobs of a campaign (used for cleaning)
  get '/campaigns/:id/jobs/finished/?' do |id|
    response['Allow'] = 'GET,POST'
    jobs=Cigri::Jobset.new(:where => "jobs.state in ('terminated','event') and jobs.campaign_id=#{id}")
    status 200
    items=jobs.records.map{|j| j.props}
    print({:items => items})
  end
 
  # Details of a job
  get '/campaigns/:id/jobs/:jobid/?' do |id, jobid|
    response['Allow'] = 'GET'

    campaign = get_campaign(id)
    task = nil
    begin
      task = campaign.task(jobid)
    rescue DBI::ProgrammingError => e
      halt 400, print({:status => 400, :title => "Error", :message => "#{e}"})
    end
    not_found unless task
    
    output = {
      :id => task['id'],
      :name => task['name'],
      :parameters => task['param'],
      :state => task['state'] || :waiting,
      :links => [
                  {:rel => :self, :href => to_url("campaigns/#{id}/jobs/#{task['id']}")},
                  {:rel => :parent, :href => to_url("campaigns/#{id}/jobs")}
                ]
    }

    jobs = []
    task[4].each do |job|
      jobs << {
        :id => job['id'],
        :cluster_id => job['cluster_id'],
        :cluster_name => job['clustername'],
        :state => job['state'],
        :return_code => job['return_code'],
        :remote_id => job['remote_id']
      }
    end

    output[:execution] = jobs

    status 200
    print(output)
  end

  # Get the events of a campaign
  get '/campaigns/:id/events/?' do |id|
    response['Allow'] = 'GET'
    
    limit = params['limit'] || 100
    offset = params['offset'] || 0

    output = get_formated_campaign_events(id, limit, offset)

    status 200
    print(output)
  end
 
  # List all clusters
  get '/clusters/?' do
    response['Allow'] = 'GET'
    items = []
    Cigri::ClusterSet.new.each do |cluster|
      id = cluster.description['id']
      items << {:id => id,
                :name => cluster.description['name'],
                :links => [
                  {:rel => :self, :href => to_url("clusters/#{id}")},
                  {:rel => :parent, :href => to_url('clusters')}
                ]
               }
    end
    output = {
      :items => items,
      :total => items.length,
      :links => [
          {:rel => :self, :href => to_url("clusters")},
          {:rel => :parent, :href => to_url('')}
        ]
    }
    
    status 200
    print(output)
  end
  
  # Details of a cluster
  get '/clusters/:id/?' do |id|
    response['Allow'] = 'GET'
    cluster=nil
    begin
      cluster = Cigri::Cluster.new(:id => id)
      cluster_desc=cluster.description
      cluster_desc['links'] = [{:rel => :self, :href => to_url("clusters/#{id}")},
                          {:rel => :parent, :href => to_url("clusters")}]
      ['api_password', 'api_username'].each { |i| cluster_desc.delete(i)}
    rescue Exception => e
      not_found
    end
    
    cluster_desc['blacklisted'] = cluster.blacklisted?
    cluster_desc['under_stress'] = cluster.under_stress?
    cluster_desc['stress_factor'] = cluster_desc['stress_factor'].to_s + "/" + STRESS_FACTOR.to_s unless cluster_desc['stress_factor'].nil?
    status 200
    print(cluster_desc)
  end

  # Delete a file on a cluster
  delete %r{/clusters/([0-9]+)/(.+)} do |id,file|
     output={:msg => "Deleting #{file} on #{id}"}
     cluster = Cigri::Cluster.new(:id => id)
     begin
       cluster.delete_file(file,request.env[settings.username_variable])
     rescue Exception => e
       halt 400, print({:status => 400, :title => "Media deletion error", :message => e.to_s})
     end
     status 202
     print(output)
  end
  
  # Submit a new campaign
  post '/campaigns/?' do
    protected!

    request.body.rewind
    answer = ''
    begin
      db_connect() do |dbh|
        id = Cigri::JDLParser.save(dbh, request.body.read, request.env[settings.username_variable]).to_s
        answer = get_formated_campaign(id)
      end
    rescue Cigri::AdmissionRuleError => e
      halt 400, print({:status => 400, :title => "Admission rule error", :message => e.to_s})
    rescue Exception => e
      halt 400, print({:status => 400, :title => "Error", :message => "Error submitting campaign: #{e}"})
    end

    status 201
    response['Location'] = to_url("campaigns/#{answer[:id]}")
    print(answer)
  end

  #adding jobs to an existing campaign
  post '/campaigns/:id/jobs/?' do |id|
    protected!
    request.body.rewind
    
    begin
      db_connect() do |dbh|
        cigri_submit_jobs(dbh, JSON.parse(request.body.read), id, request.env[settings.username_variable])
      end
    rescue Cigri::NotFound 
      not_found
    rescue Cigri::Unauthorized => e
      halt 403, print({:status => 403, :title => "Forbidden", :message => e.message})
    rescue Exception => e
      halt 400, print({:status => 400, :title => "Error", :message => "Error updating campaign #{id}: #{e}"})
    end

    status 201
    response['Location'] = to_url("campaigns/#{id}")
    print(get_formated_campaign(id))
  end
  
  # Update a campaign
  put '/campaigns/:id/?' do |id|
    protected!

    begin
      db_connect() do |dbh|
        update_campaign(dbh, request.env[settings.username_variable], id, params_to_update) 
      end   
    rescue Cigri::NotFound => e
      not_found
    rescue Cigri::Unauthorized => e
      halt 403, print({:status => 403, :title => "Forbidden", :message => "Campaign #{id} does not belong to you: #{e.message}"})
    rescue Exception => e
      halt 400, print({:status => 400, :title => "Error", :message => "Error updating campaign #{id}: #{e}"})
    end
  
    status 202
    print(get_formated_campaign(id))
  end

  delete '/events/:id/?' do |id|
    protected!

    db_connect() do |dbh|

      begin
        event=close_event(dbh, request.env[settings.username_variable], id)
        logger.debug("Closing event #{id}, #{params['resubmit']}")
        if params['resubmit'] && event.props[:job_id]
          job=Cigri::Job.new(:id=>event.props[:job_id])
          job.resubmit
        end
      rescue Cigri::NotFound => e
        not_found
      rescue Cigri::Unauthorized => e
        halt 403, print({:status => 403, :title => "Forbidden", :message => "Event #{id} is not specific to a campaign belonging to you: #{e.message}"})
      rescue Exception => e
        halt 400, print({:status => 400, :title => "Error", :message => "Error fixing event #{id}: #{e}"})
      end
    end
    status 202
    print({:status => 202, :title => :Accepted, :message => "Event #{id} closed"})
  end

  delete '/campaigns/:id/events/?' do |id|
    protected!

    db_connect() do |dbh|

      begin
        # Get the jobs to resubmit if needed
        if params['resubmit']
          dataset=Dataset.new("jobs,events",{:what => 
               "jobs.id as id,jobs.param_id as param_id,jobs.campaign_id as campaign_id,jobs.tag as tag,jobs.runner_options as runner_options",
                                             :where => "events.campaign_id=#{id} and
                                              events.state='open' and 
                                              jobs.id=events.job_id"}) 
          jobs=Cigri::Jobset.new()
          jobs.fill(dataset.records,true)
          jobs.to_jobs
        end
        # Fix the campaign
        logger.debug("Closing all events if #{id}, #{params['resubmit']}")
        close_campaign_events(dbh, request.env[settings.username_variable], id)
        # Resubmit the jobs if needed
        jobs.each{|job| job.resubmit} if params['resubmit']

      rescue Cigri::NotFound => e
        not_found
      rescue Cigri::Unauthorized => e
        halt 403, print({:status => 403, :title => "Forbidden", :message => "Campaign #{id} does not belong to you: #{e.message}"})
      rescue Exception => e
        halt 400, print({:status => 400, :title => "Error", :message => "Error fixing campaign #{id}: #{e}"})
      end
    end
 
    status 202
    print({:status => 202, :title => :Accepted, :message => "Campaign #{id} events closed"})
  end
 
  
  delete '/campaigns/:id/?' do |id|
    protected!

    msg=""
    db_connect() do |dbh|
      begin
        if params['hold']
          msg="paused"
          hold_campaign(dbh, request.env[settings.username_variable], id)
          Cigri::Event.new({:code => "PAUSED", :campaign_id => id, :class => "campaign", :message => "User request to pause the campaign #{id}", :state => 'closed'})
        elsif params['resume']
          msg="resumed"
          resume_campaign(dbh, request.env[settings.username_variable], id)
          Cigri::Event.new({:code => "RESUMED", :campaign_id => id, :class => "campaign", :message => "User request to resume the campaign #{id}", :state => 'closed'})
        else
          msg="cancelled"
          cancel_campaign(dbh, request.env[settings.username_variable], id)
          # Add a frag event to kill/clean the jobs
          Cigri::Event.new({:code => "USER_FRAG", :campaign_id => id, :class => "campaign", :message => "User request to cancel the campaign #{id}"})
        end
      rescue Cigri::NotFound => e
        not_found
      rescue Cigri::Unauthorized => e
        halt 403, print({:status => 403, :title => "Forbidden", :message => "Campaign #{id} does not belong to you: #{e.message}"})
      rescue Exception => e
        halt 400, print({:status => 400, :title => "Error", :message => "Error cancel/pause/resuming campaign #{id}: #{e}"})
      end
    end
 
    status 202
    print({:status => 202, :title => :Accepted, :message => "Campaign #{id} #{msg}"})
  end

  # List subscribed notifications
  get '/notifications/?' do
    protected!
    response['Allow'] = 'GET'
    user=request.env[settings.username_variable]
    user="%%admin%%" if user=="root"
    begin
      notifications = Dataset.new("user_notifications",:where => "grid_user = '#{user}'")
      items=[]
      notifications.each do |notification|
        items << notification.props
      end
      output={ :items => items,
               :links => [{:rel => :self, :href => to_url("notifications/")}] }
    rescue Exception => e
      halt 400, print({:status => 400, :title => "Error", :message => "Error with notification listing: #{e}"})
    end
    
    status 200
    print(output)
  end

  #new notification subscription
  post '/notifications/:type/?' do |type|
    protected!
    request.body.rewind
    not_found if type != "jabber" && type != "mail"
    subscription=JSON.parse(request.body.read)
    type="xmpp" if type == "jabber"
    subscription["type"]=type   
 
    begin
      db_connect() do |dbh|
        add_notification_subscription(dbh, subscription, request.env[settings.username_variable])
      end
    rescue Exception => e
      halt 400, print({:status => 400, :title => "Error", :message => "Error with notification subscription: #{e}"})
    end

    status 201
    print({:status => 201, :title => :Created, :message => "New subscription created"})
    #response['Location'] = to_url("/notifications/#{id}")
  end

  #unsubscription from a notification 
  delete '/notifications/:type/?' do |type|
    protected!
    not_found if type != "jabber" && type != "mail"
    type="xmpp" if type == "jabber"

    begin
      db_connect() do |dbh|
        del_notification_subscription(dbh, type, params["identity"], request.env[settings.username_variable])
      end
    rescue Exception => e
      halt 400, print({:status => 400, :title => "Error", :message => "Error with notification unsubscription: #{e}"})
    end

    status 202
    print({:status => 202, :title => :Deleted, :message => "Unsubscription ok"})
  end

  get '/gridusage/?' do
    params['from'] ? from=params['from'] : from=nil
    params['to'] ? to=params['to'] : to=nil
    items=[]
    begin
      db_connect do |dbh|
        items=get_grid_usage(dbh,from,to)
      end
    rescue Exception => e
      halt 400, print({:status => 400, :title => "Error", :message => "Error with grid_usage extract: #{e} #{e.backtrace}"})
    end
   
    output={"items" => items,
            "from" => from,
            "to" => to,
            "total" => items.length
           }

    status 200
    print(output)
 
  end

  not_found do 
    print( {:status => 404, :title => 'Not found', :message => "#{request.request_method} #{request.url} not found on this server"} )
  end

  private
    
    # Prints a json into text and use a pretty print function if pretty is given to URL
    #
    # == Parameters
    #  - json: json to print. 
    def print(json)
      if params.has_key?('pretty') && params['pretty'] != 'false'
        JSON.pretty_generate(json) << "\n"
      else
        JSON.generate(json) << "\n"
      end
    end 

    # Gets jobs from a campaign
    #
    # == Parameters: 
    #  - id: id of the campaign
    #  - limit: number of jobs to get
    #  - offset: start from job "offset"
    def get_formated_jobs(id, limit, offset)      
      campaign = get_campaign(id)
      tasks = nil
      begin
        tasks = campaign.tasks(limit, offset)
      rescue DBI::ProgrammingError => e
        halt 400, print({:status => 400, :title => "Error", :message => "#{e}"})
      end
      not_found if tasks.size == 0
     
      items = []
      tasks.each do |task|
        if task['queued_cluster'] and not task['state']
          task['state']="queued" 
          task['cluster_id']=task['queued_cluster']
        end
        items << {
          :id => task['id'],
          :name => task['name'],
          :parameters => task['param'],
          :cluster => CLUSTER_NAMES[task['cluster_id']],
          :cigri_job_id => task['cigri_job_id'],
          :remote_id => task['remote_id'],
          :state => task['state'] || :pending,
          :href => to_url("campaigns/#{id}/jobs/#{task['id']}")
        }
      end

      res={
        :items => items,
        :total => campaign.props[:nb_jobs].to_i,
        :offset => offset,
        :limit => limit,
        :links => [
                    {:rel => :self, :href => to_url("campaigns/#{id}/jobs")},
                    {:rel => :parent, :href => to_url("campaigns/#{id}")}
                  ]
      }
      if :items.length < campaign.props[:nb_jobs].to_i
        res[:links] << {:rel => :next, :href => to_url("campaigns/#{id}/jobs?limit=#{limit}&offset=#{(offset.to_i+limit.to_i+1).to_s}")}
      end
      res
    end

    # Gets global events
    #
    # == Parameters: 
    #  - limit: number of events to get
    #  - offset: start from event "offset"
    def get_formated_global_events(limit, offset)      
     events=[]
      begin
        db_connect() do |dbh|
          events = get_global_events(dbh, limit, offset)
        end
      rescue DBI::ProgrammingError => e
        halt 400, print({:status => 400, :title => "Error", :message => "#{e}"})
      end
      not_found if events.size == 0
      
      items=formated_events(events)
      {:items => items,
       :offset => offset
      }
      #TODO: compute total
    end

    # Gets events on a campaign
    #
    # == Parameters: 
    #  - id: id of the campaign
    #  - limit: number of events to get
    #  - offset: start from event "offset"
    def get_formated_campaign_events(id, limit, offset)      
      campaign = get_campaign(id)
      events = nil
      begin
        events = campaign.events(limit, offset)
      rescue DBI::ProgrammingError => e
        halt 400, print({:status => 400, :title => "Error", :message => "#{e}"})
      end
      not_found if events.size == 0
      
      items=formated_events(events)
      {:items => items,
       :total => campaign.nb_events.to_i,
       :offset => offset
      }
    end

    # Format a list of events 
    def formated_events(events)      
      items = []
      events.each do |event|
        items << {
          :id => event[0],
          :class => event[1],
          :code => event[2],
          :job_id => event[3],
          :cluster_id => event[4],
          :cluster_name => CLUSTER_NAMES[event[4]],
          :date_open => event[6],
          :message => event[5],
          :parent => event[7],
          :state => event[8]
        }
      end
      return items
    end


    # Gets a campaign from the database
    #
    # == Parameters: 
    #  - id: id of the campaign to get
    def get_campaign(id,jdl=false)
      campaign = Cigri::Campaign.new({:id => id, :jdl=>jdl})
      not_found unless campaign.props

      campaign
    end
    
    # Gets a campaign from the database and format it
    #
    # == Parameters: 
    #  - id: id if the campaign to get
    def get_formated_campaign(id,clusters_infos=false)
      format_campaign(get_campaign(id),clusters_infos)
    end
   
    # Gets some statistics about a campaign
    #
    # == Parameters: 
    #  - id: id of the campaign to get stats from
    def get_campaign_stats(id)
      campaign = Cigri::Campaign.new(:id => id)
      props=campaign.props
      avg=campaign.average_job_duration
      throughput=campaign.throughput(CAMPAIGN_THROUGHPUT_WINDOW)
      throughput=0.0000000000000001 if throughput==0
      stats={ :average_jobs_duration => avg[0],
              :stddev_jobs_duration => avg[1],
              :jobs_throughput => throughput,
              :remaining_time => (props[:nb_jobs].to_i-props[:finished_jobs].to_i)/throughput,
              :failures_rate => campaign.failures_rate,
              :resubmit_rate => campaign.resubmit_rate
            }
      return stats
    end
 
    # Gets the useful information about a campaign
    #
    # == Parameters: 
    #  - campaign: Cigri::Campaign campaign to format
    def format_campaign(campaign,clusters_infos=false)
      props = campaign.props
      clusters={}
      if clusters_infos
        campaign.get_clusters
        campaign.clusters.each_key do |c|
          clusters[c]={}
          clusters[c]["cluster_name"]=CLUSTER_NAMES[c]
          clusters[c]["active_jobs"]=campaign.active_jobs_number_on_cluster(c)
          clusters[c]["queued_jobs"]=campaign.queued_jobs_number_on_cluster(c)
          clusters[c]["prologue_ok"]=campaign.prologue_ok?(c)
          clusters[c]["epilogue_ok"]=campaign.epilogue_ok?(c)
        end
      end
      id = props[:id]
      c={
       :id => id.to_i, 
       :name => props[:name], 
       :user => props[:grid_user],
       :state => props[:state],
       :has_events => campaign.has_open_events?,
       :submission_time => Time.parse(props[:submission_time]).to_i,
       :total_jobs => props[:nb_jobs].to_i,
       :finished_jobs => props[:finished_jobs],
       :links => [
         {:rel => :self, :href => to_url("campaigns/#{id}")},
         {:rel => :parent, :href => to_url('campaigns')},
         {:rel => :collection, :href => to_url("campaigns/#{id}/jobs"), :title => 'jobs'},
         {:rel => :collection, :href => to_url("campaigns/#{id}/events"), :title => 'events'},
         {:rel => :item, :href => to_url("campaigns/#{id}/jdl"), :title => 'jdl'}
       ]}
       c["clusters"]=clusters if clusters_infos
       return c
    end

    # Gets an event from the database
    #
    # == Parameters: 
    #  - id: id of the event to get
    def get_event(id)
      event = Cigri::Event.new({:id => id})
      not_found unless event.props
      event
    end

    # Gets a job from the database
    #
    # == Parameters: 
    #  - id: id of the job to get
    def get_job(id)
      jobset = Cigri::Jobset.new({:where => "jobs.id=#{id}"})
      not_found if jobset.records.empty?
      jobset.records[0]
    end

    # Gets an event from the database and format it
    #
    # == Parameters: 
    #  - id: id if the event to get
    def get_formated_event(id)
      event=get_event(id)
      event.props[:id]=id.to_i
      event.props[:links]=[
         {:rel => :self, :href => to_url("events/#{id}")},
         {:rel => :parent, :href => to_url('events')}
      ]
      event.props[:cluster_name]=CLUSTER_NAMES[event.props[:cluster_id]],
      event.props
    end

    # Gets a job from the database and format it
    #
    # == Parameters: 
    #  - id: id if the job to get
    def get_formated_job(id)
      j=get_job(id)
      j.props[:id]=id.to_i
      j.props[:links]=[
         {:rel => :self, :href => to_url("jobs/#{id}")},
         {:rel => :parent, :href => to_url('jobs')}
      ]
      j.props[:cluster_name]=CLUSTER_NAMES[j.props[:cluster_id].to_i] if j.props[:cluster_id]
      j.props
    end
  
    # Get stderr or stdout of a given job 
    def get_job_output(id,type)
      tail=100000 # TODO: set as a parameter of the query
      job=get_job(id)
      cluster=Cigri::Cluster.new(:id => job.props[:cluster_id])
      cluster_job=cluster.get_job(job.props[:remote_id].to_i, job.props[:grid_user])
      file=cluster_job["launching_directory"]+"/"+cluster_job["#{type}_file"]
      begin
        output=cluster.get_file(file,job.props[:grid_user],tail)
      rescue Cigri::ClusterAPINotFound => e
        # warning: there's no typo here: yes, we do a halt 400 and return a 404 status
        # otherwise, the standard not_found route overrides this message
        halt 400, print( {:status => 404, :title => 'Not Found', :message => e.to_s} )
      rescue => e
        halt 400, print({:status => 400, :title => "Get media error", :message => e.to_s})   
      end
      return {:output => output}
    end
 
    def params_to_update
      res = {}
      res['name'] = params['name'].to_s if params['name']
      if params['state']
        ok_states = %w{paused in_treatment}
        if ok_states.find_index(params['state'])
          res['state'] = params['state']
        else
          halt 400, print({:status => 400, :title => "Error", :message => "Error updating campaign #{id}: state chould be in (" << ok_states.join(', ') << ")"})
        end
      end
      res
    end

    def to_url(url)
      uri = [request.env['HTTP_X_CIGRI_API_PATH_PREFIX'], url].join('/')
      uri = '/' + uri unless uri.start_with?('/')
      uri
    end
    
    def protected!
      unless authorized?
        halt 403, print({:status => 403, :title => 'Forbidden', :message => "Access denied: not authenticated"})
      end
    end
    
    def authorized?
      user = request.env[settings.username_variable]
      return user && user != "" && user !~ /^(unknown|null)$/i
    end
end
