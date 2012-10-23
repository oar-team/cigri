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
require 'jdl-parser'
require 'rack_debugger'

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
    response['Allow'] = 'GET,POST'
    
    items = []
    Cigri::Campaignset.new.get_unfinished.each do |campaign|
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
    
    status 200
    print(output)
  end

  # Details of a campaign
  get '/campaigns/:id/?' do |id|
    response['Allow'] = 'DELETE,GET,POST,PUT'
    output = get_formated_campaign(id)

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

  # Get the jdl as saved in the database
  get '/campaigns/:id/jdl/?' do |id|
    response['Allow'] = 'GET'

    campaign = get_campaign(id)

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
  
  # Details of a job
  get '/campaigns/:id/jobs/:jobid/?' do |id, jobid|
    response['Allow'] = 'GET'

    output = get_formated_jobs(id, 1, jobid)[:items][0]

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
    begin
      cluster = Cigri::Cluster.new(:id => id).description
      cluster[:links] = [{:rel => :self, :href => to_url("clusters/#{id}")},
                          {:rel => :parent, :href => to_url("clusters")}]
      ['api_password', 'api_username'].each { |i| cluster.delete(i)}
    rescue Exception => e
      not_found
    end
    
    status 200
    print(cluster)
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
               "jobs.id as id,jobs.param_id as param_id,jobs.campaign_id as campaign_id",
                                             :where => "events.campaign_id=#{id} and
                                              events.state='open' and 
                                              jobs.id=events.job_id"}) 
          jobs=Cigri::Jobset.new()
          jobs.fill(dataset.records,true)
          jobs.to_jobs
        end
        # Fix the campaign
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

    db_connect() do |dbh|
      begin
        cancel_campaign(dbh, request.env[settings.username_variable], id)
      rescue Cigri::NotFound => e
        not_found
      rescue Cigri::Unauthorized => e
        halt 403, print({:status => 403, :title => "Forbidden", :message => "Campaign #{id} does not belong to you: #{e.message}"})
      rescue Exception => e
        halt 400, print({:status => 400, :title => "Error", :message => "Error cancelling campaign #{id}: #{e}"})
      end
    end

    # Add a frag event to kill/clean the jobs   
    Cigri::Event.new({:code => "USER_FRAG", :campaign_id => id, :class => "campaign"})
 
    status 202
    print({:status => 202, :title => :Accepted, :message => "Campaign #{id} cancelled"})
  end

  # List subscribed notifications
  get '/notifications/?' do
    protected!
    response['Allow'] = 'GET'
    begin
      notifications = Dataset.new("user_notifications",:where => "grid_user = '#{request.env[settings.username_variable]}'")
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



  not_found do 
    print( {:status => 404, :title => 'Not Found', :message => "#{request.request_method} #{request.url} not found on this server"} )
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
        items << {
          :id => task[0],
          :name => task[1],
          :parameters => task[2],
          :state => task[3] || :waiting,
          :href => to_url("campaigns/#{id}/jobs/#{task[0]}")
        }
      end

      {:items => items,
       :total => campaign.props[:nb_jobs].to_i,
       :offset => offset
      }
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
      # Cluster id <-> name matching
      cluster_names = {}
      clusters=Cigri::ClusterSet.new
      clusters.each do |cluster|
       cluster_names[cluster.id]=cluster.name
      end
      begin
        events = campaign.events(limit, offset)
      rescue DBI::ProgrammingError => e
        halt 400, print({:status => 400, :title => "Error", :message => "#{e}"})
      end
      not_found if events.size == 0

      items = []
      events.each do |event|
        items << {
          :id => event[0],
          :class => event[1],
          :code => event[2],
          :job_id => event[3],
          :cluster_id => event[4],
          :cluster_name => cluster_names[event[4]],
          :date_open => event[6],
          :message => event[5],
          :parent => event[7],
          :state => event[8]
        }
      end

      {:items => items,
       :total => campaign.nb_events.to_i,
       :offset => offset
      }
    end



    # Gets a campaign from the database
    #
    # == Parameters: 
    #  - id: id of the campaign to get
    def get_campaign(id)
      campaign = Cigri::Campaign.new({:id => id})
      not_found unless campaign.props

      campaign
    end
    
    # Gets a campaign from the database and format it
    #
    # == Parameters: 
    #  - id: id if the campaign to get
    def get_formated_campaign(id)
      format_campaign(get_campaign(id))
    end
    
    # Gets the useful information about a campaign
    #
    # == Parameters: 
    #  - campaign: Cigri::Campaign campaign to format
    def format_campaign(campaign)
      props = campaign.props
      id = props[:id]
      {:id => id.to_i, 
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
      event.props
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
