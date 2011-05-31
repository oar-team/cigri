require File.join(File.expand_path(File.dirname(__FILE__)), 'config/environment')

$LOAD_PATH.unshift(File.join(ENV['CIGRIDIR'], 'lib'))

require 'cigri'
require 'jdl-parser'
require 'json'
require 'pp'
require 'sinatra'

class API < Sinatra::Base
  
  def initialize(*args)
    super 
    @apiliblogger = Cigri::Logger.new('APILIB', 'STDOUT')#Cigri.conf.get('LOG_FILE'))
  end
  
  before do
    @apiliblogger.debug("Received request: #{request.inspect}")
  end
  
  get '/' do
    Time.now.to_s + "\n"
  end

  post '/' do
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
  
  delete '/:id' do |id|
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
end
