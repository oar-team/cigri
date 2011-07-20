require File.join(File.expand_path(File.dirname(__FILE__)), 'config/environment')
$LOAD_PATH.unshift(File.join(ENV['CIGRIDIR'], 'lib'))

require 'cigri'
require 'cigri-clusterlib'
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
    headers['Allow'] = 'GET'
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
    print(output)
  end
  
  # Details of a cluster
  get '/clusters/:id' do |id|
    headers['Allow'] = 'GET'
    
    begin
      cluster = Cigri::Cluster.new(:id => id).description
      cluster["links"] = [{"rel" => "self", "href" => "/clusters/#{id}"},
                          {"rel" => "parent", "href" => "/clusters"}]
      ['api_password', 'api_username'].each { |i| cluster.delete(i)}
      print(cluster)
    rescue Exception => e
      halt 404, "Cluster with id #{id} does not exist\n"
    end
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
  put '/campaigns/:id' do |id|
    "Updating campaign #{id}"
  end
  
  delete '/campaigns/:id' do |id|
    res = ''
    db_connect() do |dbh|
      res = delete_campaign(dbh, 'root', id)
    end
    if res == nil
      halt 404, "Campaign #{id} does not exist"
    elsif res
      answer = "Campaign #{id} deleted"
    else
      #TODO erreur de permissions
      answer = "Campaign #{id} does not belong to you"
    end
    answer << "\n"
  end
  
  not_found do 
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
    
    def format_error(hash)
      content_type parser.default_mime_type
      parser.dump(hash)
    rescue Exception => e
      content_type :txt
      hash.to_a.inspect
    end
end
