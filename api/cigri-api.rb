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
    @apiliblogger = Cigri::Logger.new('APILIB', 'STDOUT')#Cigri.conf.get('LOG_FILE'))
    @apiliblogger.level = Cigri::Logger::DEBUG
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
    output = {
        'links' => [
          {'rel' => 'self', 'href' => '/'},
          {'rel' => 'campaigns', 'href' => '/campaigns', 'title' => 'campaigns'},
          {'rel' => 'clusters', 'href' => '/clusters', 'title' => 'clusters'}
        ]
      }
    response['Allow'] = 'GET'
    status 200
    print(output)
  end
  
  # List all running campaigns (in_treatment or paused)
  get '/campaigns/?' do
    #get list of campaign
    items = []
    Cigri::Campaignset.new.get_unfinished.each do |campaign|
      items << format_campaign(campaign)
    end
    output = {
      "items" => items,
      "total" => items.length,
      "links" => [
          {"rel" => "self", "href" => "/campaigns"},
          {"rel" => "parent", "href" => "/"}
        ]
    }
    response['Allow'] = 'GET,POST'
    status 200
    print(output)
  end
  
  # Details of a campaign
  get '/campaigns/:id/?' do |id|
    output = get_formated_campaign(id)
    response['Allow'] = 'DELETE,GET,POST,PUT'
    status 200
    print(output)
  end
  
  # List all jobs of a campaign
  get '/campaigns/:id/jobs/?' do |id|
    "Jobs of campaign #{id}\n"
  end
  
  # Details of a job
  get '/campaigns/:id/jobs/:jobid/?' do |id, jobid|
    "Job #{jobid} of campaaign #{id}"
  end
  
  # List all clusters
  get '/clusters/?' do
    # get all the clusters
    items  = []
    Cigri::ClusterSet.new.each do |cluster|
      id = cluster.description['id']
      items << {
                  'id' => id,
                  'name' => cluster.description['name'],
                  'links' => [
                    {'rel' => 'self', 'href' => "/clusters/#{id}"},
                    {'rel' => 'parent', 'href' => '/clusters'}
                  ]
               }
    end
    output = {
      "items" => items,
      "total" => items.length,
      "links" => [
          {"rel" => "self", "href" => "/clusters"},
          {"rel" => "parent", "href" => "/"}
        ]
    }
    response['Allow'] = 'GET'
    status 200
    print(output)
  end
  
  # Details of a cluster
  get '/clusters/:id/?' do |id|
    begin
      cluster = Cigri::Cluster.new(:id => id).description
      cluster["links"] = [{"rel" => "self", "href" => "/clusters/#{id}"},
                          {"rel" => "parent", "href" => "/clusters"}]
      ['api_password', 'api_username'].each { |i| cluster.delete(i)}
    rescue Exception => e
      not_found "Cluster with id #{id} does not exist"
    end
    response['Allow'] = 'GET'
    status 200
    print(cluster)
  end
  
  # Submit a new campaign
  post '/campaigns/?' do
    protected!
    request.body.rewind
    answer = ''
    db_connect() do |dbh|
      begin
        id = Cigri::JDLParser.save(dbh, request.body.read, request.env['HTTP_X_CIGRI_USER']).to_s
        answer = {
          "id" => id,
          "links" => [
            {"rel" => "self", "href" => "/campaigns/#{id}"},
            {"rel" => "parent", "href" => "/campaigns"}
          ]
        }
        status 201
      rescue Exception => e
        status 400
        answer = e.message
      end
    end
    response['Allow'] = 'GET,POST'
    print(answer)
  end
  
  # Update a campaign
  put '/campaigns/:id/?' do |id|
    protected!
    
    to_update = {}
    to_update['name'] = params['name'].to_s if params['name']
    if params['state']
      ok_states = %w{paused in_treatment}
      if ok_states.find_index(params['state'])
        to_update['state'] = params['state']
      else
        halt 400, "Error updating campaign #{id}: state chould be in ( " << ok_states.join(', ') << ")\n"
      end
    end
    
    res = nil
    db_connect() do |dbh|
      begin
        res = update_campaign(dbh, request.env['HTTP_X_CIGRI_USER'], id, to_update)
      rescue Exception => e
        halt 400, "Error updating campaign #{id}: #{e}"
      end
    end
    
    if res == nil
      not_found "Campaign #{id} does not exist"
    elsif res
      status 202
      output = get_formated_campaign(id)
    else
      status 403
      output = {:status => 403, :title => "Forbidden", :message => "Campaign #{id} does not belong to you"}
    end
    
    response['Allow'] = 'DELETE,GET,POST,PUT'
    print(output)
  end
  
  delete '/campaigns/:id/?' do |id|
    protected!
    
    res = nil
    db_connect() do |dbh|
      res = cancel_campaign(dbh, request.env['HTTP_X_CIGRI_USER'], id)
    end
    
    if res.nil?
      not_found "Campaign #{id} does not exist" if res.nil?
    elsif res == false
      status 403
      output = {:status => 403, :title => "Forbidden", :message => "Campaign #{id} does not belong to you"}
    elsif res > 0
      status 202
      output = {:status => 202, :title => "Accepted", :message => "Campaign #{id} cancelled"}
    else
      status 202
      output = {:status => 202, :title => "Accepted", :message => "Campaign #{id} was already cancelled"}
    end
    
    response['Allow'] = 'DELETE,GET,POST,PUT'
    print(output)
  end
  
  not_found do 
    print( {:status => 404, :title => "Not Found", :message => (response.body || "Not Found")} )
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
      not_found "Campaign with id '#{id}' does not exist" unless campaign.props

      output = format_campaign(campaign)
      output["links"] = [{"rel" => "self", "href" => "/campaigns/#{id}"},
                         {"rel" => "parent", "href" => "/campaigns"},
                         {"rel" => "jobs", "href" => "/campaigns/#{id}/jobs"}]
      output
    end
    
    # Gets the useful information about a campaign
    #
    # == Parameters: 
    #  - campaign: Cigri::Campaign campaign to format
    def format_campaign(campaign)
      props = campaign.props
      id = props[:id]
      {'id' => id.to_i, 
       'name' => props[:name], 
       'user' => props[:grid_user],
       'state' => props[:state],
       'submission_time' => Time.parse(props[:submission_time]).to_i,
       'total_jobs' => props[:nb_jobs].to_i,
       'finished_jobs' => props[:finished_jobs],
       'links'=> [
         {'rel' => 'self', 'href' => "/campaigns/#{id}"},
         {'rel' => 'parent', 'href' => '/campaigns'},
         {'rel' => 'collection', 'href' => "/campaigns/#{id}/jobs", 'title' => 'jobs'}
       ]}
    end
    
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        halt 401, "Access denied to cancel campaign: not authenticated"
      end
    end
    
    def authorized?
      #TODO set the value in apache
      request.env['HTTP_X_CIGRI_USER'] = 'API'
      user = request.env['HTTP_X_CIGRI_USER']
      return user && user != "" && user !~ /^(unknown|null)$/i
    end
end
