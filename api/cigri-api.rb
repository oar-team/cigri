require File.join(File.expand_path(File.dirname(__FILE__)), 'config/environment')
$LOAD_PATH.unshift(File.join(ENV['CIGRIDIR'], 'lib'))

require 'cigri'
require 'cigri-clusterlib'
require 'cigri-joblib'
require 'jdl-parser'
require 'json'
require 'sinatra'
require 'time'

class API < Sinatra::Base
  
  def initialize(*args)
    super 
    @apiliblogger = Cigri::Logger.new('APILIB', Cigri.conf.get('LOG_FILE'))
  end
  
  before do
    content_type :json
    @apiliblogger.debug("Received request: #{request.inspect}")
    if request.env['REQUEST_METHOD'] == 'POST'
      if params['action'] == 'delete'
        request.env['REQUEST_METHOD'] = 'DELETE'
      elsif
        params['action'] == 'update'
        request.env['REQUEST_METHOD'] = 'PUT'
      end
    end
  end
  
  # List all links
  get '/' do
    response['Allow'] = 'GET'
    output = {
        :links => [
          {:rel => 'self', :href => '/'},
          {:rel => 'collection', :href => '/campaigns', 'title' => :campaigns},
          {:rel => 'collection', :href => '/clusters', 'title' => :clusters}
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
          {:rel => :self, :href => "/campaigns"},
          {:rel => :parent, :href => "/"}
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

  # Get the jdl as saved in the database
  get '/campaigns/:id/jdl/?' do |id|
    response['Allow'] = 'GET'

    campaign = Cigri::Campaign.new({:id => id})
    not_found unless campaign.props

    status 200
    print(JSON.parse(campaign.props[:jdl]))
  end
  
  # List all jobs of a campaign
  get '/campaigns/:id/jobs/?' do |id|
    response['Allow'] = 'GET,POST'

    campaign = Cigri::Campaign.new({:id => id})
    not_found unless campaign.props
    puts campaign.tasks
  end
  
  # Details of a job
  get '/campaigns/:id/jobs/:jobid/?' do |id, jobid|
    response['Allow'] = 'GET'
    "Job #{jobid} of campaaign #{id}"
  end
  
  # List all clusters
  get '/clusters/?' do
    response['Allow'] = 'GET'
    items  = []
    Cigri::ClusterSet.new.each do |cluster|
      id = cluster.description['id']
      items << {:id => id,
                :name => cluster.description['name'],
                :links => [
                  {:rel => :self, :href => "/clusters/#{id}"},
                  {:rel => :parent, :href => '/clusters'}
                ]
               }
    end
    output = {
      :items => items,
      :total => items.length,
      :links => [
          {:rel => :self, :href => "/clusters"},
          {:rel => :parent, :href => "/"}
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
      cluster[:links] = [{:rel => "self", :href => "/clusters/#{id}"},
                          {:rel => "parent", :href => "/clusters"}]
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
        id = Cigri::JDLParser.save(dbh, request.body.read, request.env['HTTP_X_CIGRI_USER']).to_s
        answer = get_formated_campaign(id)
      end
    rescue Exception => e
      halt 400, print({:status => 400, :title => "Error", :message => "Error submitting campaign: #{e}"})
    end

    status 201
    response['Location'] = url("/campaigns/#{answer[:id]}")
    print(answer)
  end

  #adding jobs to an existing campaign
  post '/campaigns/:id/jobs/?' do |id|
    protected!
    request.body.rewind
    
    begin
      db_connect() do |dbh|
        cigri_submit_jobs(dbh, JSON.parse(request.body.read), id, request.env['HTTP_X_CIGRI_USER'])
      end
    rescue Cigri::NotFound 
      not_found
    rescue Cigri::Unauthorized => e
      halt 403, print({:status => 403, :title => "Forbidden", :message => e.message})
    rescue Exception => e
      halt 400, print({:status => 400, :title => "Error", :message => "Error updating campaign #{id}: #{e}"})
    end

    status 201
    response['Location'] = url("/campaigns/#{id}")
    print(get_formated_campaign(id))
  end
  
  # Update a campaign
  put '/campaigns/:id/?' do |id|
    protected!

    db_connect() do |dbh|
      begin
        update_campaign(dbh, request.env['HTTP_X_CIGRI_USER'], id, params_to_update)
      rescue Cigri::NotFound => e
        not_found
      rescue Cigri::Unauthorized => e
        halt 403, print({:status => 403, :title => "Forbidden", :message => "Campaign #{id} does not belong to you: #{e.message}"})
      rescue Exception => e
        halt 400, print({:status => 400, :title => "Error", :message => "Error updating campaign #{id}: #{e}"})
      end
    end
    
    status 200
    print(get_formated_campaign(id))
  end
  
  delete '/campaigns/:id/?' do |id|
    protected!

    res = nil
    db_connect() do |dbh|
      res = cancel_campaign(dbh, request.env['HTTP_X_CIGRI_USER'], id)
    end
    
    not_found if res.nil?
    halt 403, print({:status => 403, :title => :Forbidden, :message => "Campaign #{id} does not belong to you"}) if res == false
    
    if res > 0
      message = "Campaign #{id} cancelled"
    else
      message = "Campaign #{id} was already cancelled"
    end
    
    status 202
    print({:status => 202, :title => :Accepted, :message => message})
  end
  
  not_found do 
    print( {:status => 404, :title => 'Not Found', :message => "#{request.url} not found on this server"} )
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
    
    # Gets a campaign from the database and format it
    #
    # == Parameters: 
    #  - id: id if the campaign to get
    def get_formated_campaign(id)
      campaign = Cigri::Campaign.new({:id => id})
      not_found unless campaign.props

      format_campaign(campaign)
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
       :submission_time => Time.parse(props[:submission_time]).to_i,
       :total_jobs => props[:nb_jobs].to_i,
       :finished_jobs => props[:finished_jobs],
       :links=> [
         {:rel => :self, :href => "/campaigns/#{id}"},
         {:rel => :parent, :href => '/campaigns'},
         {:rel => :collection, :href => "/campaigns/#{id}/jobs", :title => 'jobs'},
         {:rel => :item, :href => "/campaigns/#{id}/jdl", :title => 'jdl'}
       ]}
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
    
    def protected!
      unless authorized?
        halt 403, print({:status => 403, :title => 'Forbidden', :message => "Access denied: not authenticated"})
      end
    end
    
    def authorized?
      user = request.env['HTTP_X_CIGRI_USER']
      return user && user != "" && user !~ /^(unknown|null)$/i
    end
end
