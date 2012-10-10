#!/usr/bin/ruby -w

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-notificationlib'
require 'cigri-conflib'
config = Cigri.conf
logger = Cigri::Logger.new("JUDAS #{ARGV[0]}", config.get('LOG_FILE'))

$0 = "Cigri: judas #{ARGV[0]}"

begin
  require 'net/smtp'
  SMTPLIB||=true
rescue LoadError
  SMTPLIB||=false
  logger.warn("Net/smtp lib not found: mail notifications will be disabled!")
end
begin
  require 'xmpp4r/client'
  XMPPLIB||=true
rescue LoadError
  XMPPLIB||=false
  logger.warn("Xmpp4r lib not found: xmpp notifications will be disabled!")
end
IRCLIB=false

# Signal traping
%w{INT TERM}.each do |signal|
  Signal.trap(signal){ 
    #cleanup!
    logger.warn('Interruption caught: exiting.')
    exit(1)
  }
end

logger.info("Starting judas (notification module)")

# Connexion handlers
im_handlers={}
if XMPPLIB
  # Xmpp connexion
  if config.exists?("NOTIFICATIONS_XMPP_SERVER")
    begin
      jid = Jabber::JID.new(config.get("NOTIFICATIONS_XMPP_IDENTITY"))
      im_handlers[:xmpp] = Jabber::Client.new(jid)
      im_handlers[:xmpp].connect(config.get("NOTIFICATIONS_XMPP_SERVER"),config.get("NOTIFICATIONS_XMPP_PORT",5222))
      im_handlers[:xmpp].auth(config.get("NOTIFICATIONS_XMPP_PASSWORD"))
    rescue => e
      logger.error("Could not connect to XMPP server, notifications disabled: #{e.inspect}")
      im_handlers[:xmpp]=nil
    end
  end
end
if IRCLIB
  # Irc connexion goes here
end

# Main loop
while true do
  logger.debug('New iteration')

  # Just for testing:
  message=Cigri::Message.new({:admin => true, :user => "kameleon", :message => "Test message!"},im_handlers)
  message.send

  # Main sleep
  sleep 10
end
