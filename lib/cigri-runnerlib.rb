#!/usr/bin/ruby -w
#
# This library contains the Runner class
#

require 'cigri-logger'
require 'cigri-conflib'

CONF=Cigri.conf unless defined? CONF
RUNNERLIBLOGGER = Cigri::Logger.new('RUNNERLIB', CONF.get('LOG_FILE'))

module Cigri


  # Runner class
  # A runner instance is an iteration of the runner module
  # on a given cluster
  class Runner
    attr_reader :cluster

    # Creates a new runner instance
    def initialize(cluster)
      @cluster=cluster
      @dbh=db_connect()
    end

    

end
