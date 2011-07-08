require File.join(File.expand_path(File.dirname(__FILE__)), 'config/environment')
$LOAD_PATH.unshift(File.join(ENV['CIGRIDIR'], 'lib'))

require 'cigri'
require 'cigri-joblib'
require 'jdl-parser'
require 'json'
require 'sinatra'

class API < Sinatra::Base
  
  def initialize(*args)
    super 
    @apiliblogger = Cigri::Logger.new('APILIB', 'STDOUT')#Cigri.conf.get('LOG_FILE'))
  end
  
  before do
    @apiliblogger.debug("Received request: #{request.inspect}")
  end
  
  # List all links
  get '/' do
    headers['Allow'] = 'GET'
    output = {
        'links' => [
          {'rel' => 'self', 'href' => '/'},
          {'rel' => 'campaigns', 'href' => '/campaigns', 'title' => 'campaigns'},
          {'rel' => 'clusters', 'href' => '/clusters', 'title' => 'clusters'}
        ]
      }
    print(output)
  end
  
  # List all running campaigns (in_treatment or paused)
  get '/campaigns' do
    headers['Allow'] = 'DELETE,GET,POST,PUT'
    #get list of campaign
    items = []
    Cigri::Campaignset.new.get_unfinished.each do |campaign|
      id = campaign.props[:id]
      items << {
                  'id' => id, 
                  'name' => campaign.props[:name], 
                  'user' => campaign.props[:grid_user],
                  'state' =>campaign.props[:state],
                  'links'=> [
                    {'rel' => 'self', 'href' => "/campaigns/#{id}"},
                    {'rel' => 'parent', 'href' => '/campaigns'},
                    {'rel' => 'collection', 'href' => "/campaigns/#{id}/jobs", 'title' => 'jobs'}
                  ]
               }
    end
    output = {
      "items" => items,
      "total" => items.length,
      "links" => [
          {"rel" => "self", "href" => "/campaigns"},
          {"rel" => "parent", "href" => "/"}
        ]
    }
    print(output)
  end
  
  # Details of a campaign
  get '/campaigns/:id' do |id|
    "Details of campaign #{id}"
  end
  
  # List all jobs of a campaign
  get '/campaigns/:id/jobs' do |id|
    "Jobs of campaign #{id}"
  end
  
  # Details of a job
  get '/campaigns/:id/jobs/:jobid' do |id, jobid|
    "Job #{jobid} of campaaign #{id}"
  end
  
  # List all clusters
  get '/clusters' do
    response[]
    campaigns = Cigri::Campaigns.new
    campaigns.get_unfinished
    #"List of all campaigns"
    pp campaigns
  end
  
  # Details of a cluster
  get '/clusters/:id' do |id|
    "Details of cluster #{id}"
  end
  
  # Submit a new campaign
  post '/campaigns' do
    answer = ''
    request.body.rewind
    db_connect() do |dbh|
      begin
        id = Cigri::JDLParser.save(dbh, request.body.read, 'user')
        answer = id.to_s
      rescue Exception => e
        answer = e.inspect
      end
    end
    answer << "\n"
  end
  
  # Update a campaign
  put '/camapigns/:id' do |id|
    "Updating campaign #{id}"
  end
  
  delete '/camapigns/:id' do |id|
    res = ''
    db_connect() do |dbh|
      res = delete_campaign(dbh, 'root', id)
    end
    if res == nil
      answer = "Campaign #{id} does not exist"
    elsif res
      answer = "Campaign #{id} deleted"
    else
      answer = "Campaign #{id} does not belong to you"
    end
    answer << "\n"
  end
  
  not_found do 
    status 404
    format_error( {:code => 404, :title => "Not Found", :message => (response.body || "Not Found")} )
  end
  
  private
    def print(output)
      if params.has_key?("pretty")
        JSON.pretty_generate(output) << "\n"
      else
        JSON.generate(output) << "\n"
      end
    end
end
