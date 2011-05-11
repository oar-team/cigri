$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'cigri'
require 'jdl-parser'
require 'json'
require 'pp'
require 'sinatra'

APILIBLOGGER = Cigri::Logger.new('APILIB', '/tmp/test')#Cigri.conf.get('LOG_FILE'))
    
get '/' do
  sleep 5
  Time.now.to_s
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
