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
    #@apiliblogger.level = Cigri::Logger::DEBUG
  end
  
  before do
    content_type :json
    @apiliblogger.debug("Received request: #{request.inspect}")
    if request.env['REQUEST_METHOD'] == 'POST'
      if params['action'] == 'delete'
        request.env['REQUEST_METHOD'] = 'DELETE'
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
    headers['Allow'] = 'GET'
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
    headers['Allow'] = 'GET,POST'
    status 200
    print(output)
  end
  
  # Details of a campaign
  get '/campaigns/:id/?' do |id|
    campaign = Cigri::Campaign.new({:id => id})
    if campaign.props
      output = format_campaign(campaign)
      output["links"] = [{"rel" => "self", "href" => "/campaigns/#{id}"},
                         {"rel" => "parent", "href" => "/campaigns"},
                         {"rel" => "jobs", "href" => "/campaigns/#{id}/jobs"}]
    else
      not_found "Campaign with id '#{id}' does not exist"
    end
    headers['Allow'] = 'DELETE,GET,POST,PUT'
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
    headers['Allow'] = 'GET'
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
    headers['Allow'] = 'GET'
    status 200
    print(cluster)
  end
  
  # Submit a new campaign
  post '/campaigns/?' do
    halt 403, "Access denied to POST campaign: not authenticated" unless authorized
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
        answer = e.inspect
      end
    end
    headers['Allow'] = 'GET,POST'
    print(answer)
  end
  
  # Update a campaign
  put '/campaigns/:id/?' do |id|
    "Updating campaign #{id}"
  end
  
  delete '/campaigns/:id/?' do |id|
    halt 403, "Access denied to delete campaign: not authenticated" unless authorized
    res = ''
    db_connect() do |dbh|
      res = delete_campaign(dbh, request.env['HTTP_X_CIGRI_USER'], id)
    end
    if res == nil
      not_found "Campaign #{id} does not exist"
    elsif res
      status 202
      answer = "Campaign #{id} deleted"
    else
      status 403
      answer = "Campaign #{id} does not belong to you"
    end
    headers['Allow'] = 'DELETE,GET,POST,PUT'
    answer << "\n"
  end
  
  not_found do 
    format_error( {:code => 404, :title => "Not Found", :message => (response.body || "Not Found")} )
  end
  
  private
    
    # Choose the printing method
    def print(output)
      if params.has_key?('pretty') && params['pretty'] != 'false'
        JSON.pretty_generate(output) << "\n"
      else
        JSON.generate(output) << "\n"
      end
    end 
    
    # Gets the useful information about a campaign
    #
    # == Parameters: 
    #  - campaign: Cigri::Campaign campaign to format
    def format_campaign(campaign)
      props = campaign.props
      id = props[:id]
      return {
               'id' => id, 
               'name' => props[:name], 
               'user' => props[:grid_user],
               'state' => props[:state],
               'submission_time' => Time.parse(props[:submission_time]).to_i,
               'links'=> [
                 {'rel' => 'self', 'href' => "/campaigns/#{id}"},
                 {'rel' => 'parent', 'href' => '/campaigns'},
                 {'rel' => 'collection', 'href' => "/campaigns/#{id}/jobs", 'title' => 'jobs'}
               ]
            }
    end
    
    def authorized
      #TODO set the value in apache
      request.env['HTTP_X_CIGRI_USER'] = 'API'
      user = request.env['HTTP_X_CIGRI_USER']
      return user && user != "" && user !~ /^(unknown|null)$/i
    end
        
    def format_error(hash)
      JSON.generate(hash) << "\n"
      #content_type parser.default_mime_type
      #parser.dump(hash)
    rescue Exception => e
      content_type :txt
      hash.to_a.inspect + "\n"
    end
end
