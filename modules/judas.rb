#!/usr/bin/ruby

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'cigri'
require 'cigri-notificationlib'
require 'cigri-conflib'
require 'cigri-joblib'
require 'cigri-colombolib'

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
      im_handlers[:xmpp].send(Jabber::Presence.new.set_show(nil).set_status('I am the grid!'))
    rescue => e
      logger.error("Could not connect to XMPP server, notifications disabled: #{e.inspect}")
      im_handlers[:xmpp]=nil
    end
  end
end
if IRCLIB
  # Irc connexion goes here
end

# Notify function
def notify(im_handlers)
  # Notify all open events
  events=Cigri::Eventset.new(:where => "state='open' and notified=false")
  Cigri::Colombo.new(events).notify(im_handlers)

  # Notify events of the class notify (events created closed, just for notification)
  events=Cigri::Eventset.new(:where => "class='notify' and notified=false")
  Cigri::Colombo.new(events).notify(im_handlers)
end

# Setting up trap on USR1
trap("USR1") {
  logger.debug("Received USR1, so checking notifications")
  notify(im_handlers)
}

# Main loop
logger.info("Ready")
while true do
  sleep 10
end
