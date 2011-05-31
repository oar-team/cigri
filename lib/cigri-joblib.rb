#!/usr/bin/ruby -w
#
# This library contains the classes relative to Jobs
#

require 'cigri-logger'
require 'cigri-conflib'
require 'cigri-iolib'

CONF=Cigri.conf unless defined? CONF
JOBLIBLOGGER = Cigri::Logger.new('JOBLIB', CONF.get('LOG_FILE'))

module Cigri


  # Job class
  # A Job instance can be get from the database or newly created
  class Job < Datarecord
    attr_reader :props

    # Creates a new job or get it from the database
    def initialize(props={})
      super("jobs",props)
    end

  end # class Job
end # module Cigri
