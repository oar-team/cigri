p File.join(File.expand_path(File.dirname(__FILE__)), 'config/environment')
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
    @apiliblogger = Cigri::Logger.new('APILIB', '/tmp/test')#Cigri.conf.get('LOG_FILE'))
  end
  
  get '/' do
    @apiliblogger.info("Received request: #{request.inspect}")
    Time.now.to_s + "\n"
  end

  post '/' do
    APILIBLOGGER.info('Reveiced request:' + request.inspect)
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
    answer += "\n"
  end
end
