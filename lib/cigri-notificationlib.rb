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
#                             :type => "info", user => "kameleon")
#  message.send

require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-iolib'

NOTIFICATIONLIBLOGGER = Cigri::Logger.new('NOTIFICATIONLIB', CONF.get('LOG_FILE'))

config = Cigri.conf

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
    # A hash containing :user, :admin, :campaign_id, :severity, :type, :message
    ##
    def initialize(opts = {})
      @user=opts[:user] || nil
      @admin=opts[:admin] || nil
      @campaign_id=opts[:campaign_id] || nil # Not implemented yet
      @severity=opts[:severity] || "low"
      @type=opts[:type] || "info"
      
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
    # Sends the message with the different notification methods
    #
    def send
      (@user_notifications+@admin_notifications).each do |notification|
        case notification.props[:type] 
          when "mail"
            #TODO
            NOTIFICATIONLIBLOGGER.warn("Mail notification method not yet implemented!")
          when "xmpp"
            #TODO
            NOTIFICATIONLIBLOGGER.warn("Xmpp notification method not yet implemented!")
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
