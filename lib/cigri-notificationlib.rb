#!/usr/bin/ruby -w
#
# Cigri notifications library
# It is used to create "Message" objects that are sent to different 
# notification services.
# For a user to receive notifications, she has to subscribe to a notification 
# service. User's subscribtion results in an entry into the user_notifications
# table (made via the API)
#
# == Example:
#  message=Cigri::Message.new(:message => "Hello world", :severity => "low", 
#                             :subject => "test", user => "kameleon")
#  message.send

require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-iolib'
begin
  require 'net/smtp'
  SMTPLIB=true
rescue LoadError
  SMTPLIB=false
end
begin
  require 'xmpp4r/client'
  XMPPLIB=true
rescue LoadError
  XMPPLIB=false
end

NOTIFICATIONLIBLOGGER = Cigri::Logger.new('NOTIFICATIONLIB', CONF.get('LOG_FILE'))
CONF = Cigri.conf unless defined? CONF

module Cigri
  # Message class
  # A message may be sent to a user, the admin or a campaign channel 
  # The notification method (xmpp, mail,...) is got from the user_notifications table.
  # If a user has several notification methods, the message is sent to all of them.
  # The campaign_id case only works for chat services, where a channel can be created
  class Message
    ##
    # Creates a new message to be sent
    # == Parameters
    # - A hash containing :user, :admin, :campaign_id, :severity, :subject, :message
    # - handlers is a hash containing connexion handlers to notification services (for example handlers[:xmpp])
    ##
    def initialize(opts = {},handlers=nil)
      @user=opts[:user] || nil
      @admin=opts[:admin] || nil
      @campaign_id=opts[:campaign_id] || nil # Not implemented yet
      @severity=opts[:severity] || "low"
      @subject=opts[:subject] || "info"
      @message=opts[:message] || "<empty message>"
      @handlers=handlers      

      if @user
        @user_notifications=Dataset.new("user_notifications",:where => "grid_user='#{@user}'")
        NOTIFICATIONLIBLOGGER.warn("No notification method for #{@user}!") if @user_notifications.length < 1
      end
      if @admin
        @admin_notifications=Dataset.new("user_notifications",:where => "grid_user='%%admin%%'")
        NOTIFICATIONLIBLOGGER.warn("No notification method for the grid administrator!") if @admin_notifications.length < 1
      end
    end

    ##
    # Get the from e-mail address from configuration
    #
    def from
      CONF.get("NOTIFICATIONS_SMTP_FROM","cigri@please.configure.me")
    end

    ##
    # Format an e-mail message
    #
    def formatted_mail(to)
      msgstr = "From: #{from}\nTo: #{to}\n"
      msgstr += "Subject: #{CONF.get('NOTIFICATIONS_SMTP_SUBJECT_TAG','[CIGRI]')} (#{@severity}): #{@subject}" 
      msgstr += "\n"
      msgstr += @message
      msgstr
    end

    ##
    # Format an im message
    #
    def formatted_im
      msgstr = "#{CONF.get('NOTIFICATIONS_SMTP_SUBJECT_TAG','[CIGRI]')} (#{@severity}): #{@subject}\n" 
      msgstr += @message
      msgstr
    end

    ## 
    # Sends the message with the different notification methods
    #
    def send
      (@user_notifications+@admin_notifications).each do |notification|
        to=notification.props[:identity]
        case notification.props[:type] 
          # Mail notifications
          when "mail"
            if CONF.exists?("NOTIFICATIONS_SMTP_SERVER")
              if SMTPLIB
                begin
                  Net::SMTP.start(CONF.get("NOTIFICATIONS_SMTP_SERVER"), CONF.get("NOTIFICATIONS_SMTP_PORT",25)) do |smtp|
                      smtp.send_message formatted_mail(to), from, to
                  end
                rescue => e
                  NOTIFICATIONLIBLOGGER.error(e.message)
                end
              else
                NOTIFICATIONLIBLOGGER.warn("Net/smtp library not found. Disabling MAIL notifications! ")
              end
            else
              NOTIFICATIONLIBLOGGER.debug("Mail notifications are disabled (no NOTIFICATIONS_SMTP_SERVER variable)")
            end
          # Xmpp notifications
          when "xmpp"
            if CONF.exists?("NOTIFICATIONS_XMPP_SERVER")
              if XMPPLIB
                if @handlers[:xmpp]
                  message=Jabber::Message.new(to,formatted_im)
                  @handlers[:xmpp].send(message)
                else
                  NOTIFICATIONLIBLOGGER.error("No XMPP handler!")
                end
              else
                NOTIFICATIONLIBLOGGER.warn("Xmpp4r library not found. Disabling XMPP notifications! ")
              end
            else
              NOTIFICATIONLIBLOGGER.debug("Xmpp notifications are disabled (no NOTIFICATIONS_XMPP_SERVER variable)")
            end
          else
            NOTIFICATIONLIBLOGGER.error("#{notification.props[:type]} notification method unknown!")
        end
      end
      if @campaign_id
        #TODO
        NOTIFICATIONLIBLOGGER.warn("Notification to a campaign_id channel not yet implemented!")
      end
    end

  end
end
