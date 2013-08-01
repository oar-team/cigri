#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib'))

require 'cigri-clientlib'
require 'json'
require 'optparse'
require 'version.rb'

verbose = false
mail_identity = nil
jabber_identity = nil
unsubscribe = false
severity = nil
list = false

optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} [options]"
  
  opts.on('-v', '--verbose', 'Be verbose') do
    verbose = true
  end

  opts.on( '-l', '--list', String, 'List notifications' ) do |l|
    list = true
  end

  opts.on( '-m', '--mail <address>', String, 'Subscribe to e-mail notifications with the given e-mail address' ) do |m|
    mail_identity = m
  end

  opts.on( '-j', '--jabber <identity>', String, 'Subscribe to Jabber notifications with the given identity' ) do |j|
    jabber_identity = j
  end
   
  opts.on('-u', '--unsubscribe', 'Unsubscribe from the specified notifications') do |u|
    unsubscribe = true
  end

  opts.on('-s', '--severity <low|medium|high>', String, 'Set the severity of notifications to low,medium or high') do |s|
    severity = s
  end

  opts.on( '--version', 'Display Cigri version' ) do
    puts "#{File.basename(__FILE__)} v#{Cigri::VERSION}"
    exit
  end
  
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end

end

begin
  optparse.parse!(ARGV)
rescue OptionParser::ParseError => e
  $stderr.puts e
  $stderr.puts "\n" + optparse.to_s
  exit 1
end

if not mail_identity and not jabber_identity and not list
  puts optparse.help
  exit
end

url = "/notifications"
if mail_identity
  url << "/mail"
  identity=mail_identity
elsif jabber_identity
  url << "/jabber"
  identity=jabber_identity
end


if !unsubscribe and identity
  if severity != "low" and severity != "medium" and severity != "high"
     $stderr.puts "ERROR: Severity should be 'low', 'medium' or 'high'!"
    exit 2
  end
end

begin 
  client = Cigri::Client.new 
  if list
    response = client.get(url+"?pretty=true")
    parsed_response = JSON.parse(response.body)
    if not parsed_response["items"].empty?
      puts "You have the following notification subscriptions:"
    end
    parsed_response["items"].each do |notif|
      notif["type"]="jabber" if notif["type"] == "xmpp"
      notif["severity"]="medium" if notif["severity"].to_s == ""
      puts " - #{notif["type"]} on #{notif["identity"]} with severity #{notif["severity"]}"
    end
  elsif unsubscribe
    response = client.delete(url+"?identity="+identity)
  else
    body={"identity" => identity, "severity" => severity}.to_json
    response = client.post(url,body, 'Content-Type' => 'application/json')
    parsed_response = JSON.parse(response.body)
    if response.code != "201"
      STDERR.puts("Failed to subscribe with #{identity}: #{parsed_response['message']}.")
    else
      puts "#{parsed_response['message']}." if verbose
    end
  end
rescue Errno::ECONNREFUSED => e
  STDERR.puts("API server not reachable: #{e.inspect}")
rescue Exception => e
  STDERR.puts("Something unexpected happened: #{e.inspect}")
  STDERR.puts e.backtrace
end

