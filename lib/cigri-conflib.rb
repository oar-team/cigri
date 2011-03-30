#!/usr/bin/ruby -w
#
# Cigri configuration library
#
# Usage example:
#
#  $LOAD_PATH << './lib'
#  require 'cigri-conflib'
#  config=Cigri::Conf.new
#  puts config.get("INSTALL_PATH")
#
#

require 'cigri-logger'

module Cigri

  if ENV['CIGRICONFDIR'] && File.exists?("#{ENV['CIGRICONFDIR']}/cigri.conf")
  then
    # Get the cigri.conf config file from the $CIGRICONFDIR directory
    CONFIG_FILE="#{ENV['CIGRICONFDIR']}/cigri.conf"
  elsif ENV['CIGRIDIR'] && File.exists?("#{ENV['CIGRIDIR']}/cigri.conf")
    # or get the cigri.conf config file from the $CIGRIDIR directory
    CONFIG_FILE="#{ENV['CIGRIDIR']}/cigri.conf"
  elsif File.exists?("./cigri.conf")
    # or get the cigri.conf config file from the current directory
    CONFIG_FILE="./cigri.conf"
  else
    # or at a last resort, get the cigri.conf config file from the /etc/ directory
    CONFIG_FILE="/etc/cigri.conf"
  end
  
  class Conf
    attr_reader :conf
    attr_accessor :config_file
  
    # Open the cigri configuration file and scan it
    def initialize(config_file = CONFIG_FILE)
      @logger = Cigri::Logger.new('Conflib', STDOUT)
      begin
        @config_file=config_file
        self.scan
      rescue
        @logger.error("unable to open config file #{config_file}!")
        exit 1
      end
    end
  
    # Scan (or re-scan) the configuration file and return the number of variables
    def scan
      @conf={}
      file=File.new(@config_file,"r")
      file.each do |line|
        a=line.scan(/^\s*([^#=\s]+)\s*=\s*"([^#]*)"/)
        key,val=a[0]
        @conf[key]=val if key
      end
      return @conf.length
    end  
 
    # Return true if the given configuration variable (key) exists
    def exists?(key)
      @conf.has_key?(key)
    end
 
    # Return the value of the given configuration variable
    def get(key)
      if @conf.has_key?(key)
        return @conf[key]
      else
        @logger.error("Conf: no key #{key}")
        exit 2
      end
    end
  end 
end
