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

require 'cigri-exception'

module Cigri

  if ENV['CIGRICONFDIR'] && File.readable?("#{ENV['CIGRICONFDIR']}/cigri.conf")
  then
    # Get the cigri.conf config file from the $CIGRICONFDIR directory
    CONFIG_FILE = "#{ENV['CIGRICONFDIR']}/cigri.conf"
  elsif ENV['CIGRIDIR'] && File.readable?("#{ENV['CIGRIDIR']}/cigri.conf")
    # or get the cigri.conf config file from the $CIGRIDIR directory
    CONFIG_FILE = "#{ENV['CIGRIDIR']}/cigri.conf"
  elsif File.readable?('./cigri.conf')
    # or get the cigri.conf config file from the current directory
    CONFIG_FILE = './cigri.conf'
  elsif File.readable?('./etc/cigri.conf')
    # or get the cigri.conf config etc directory from the current directory
    CONFIG_FILE = './etc/cigri.conf'
  else
    # or at a last resort, get the cigri.conf config file from the /etc/ directory
    CONFIG_FILE = "/etc/cigri/cigri.conf"
  end
  
  #Only read the configuration file once.
  @conf = nil
  def conf
    return @conf if @conf
    @conf = Cigri::Conf.new()
  end
  module_function :conf
  
  class Conf
    attr_reader :conf
    attr_accessor :config_file
  
    # Open the cigri configuration file and scan it
    def initialize(config_file = CONFIG_FILE)
      @config_file = config_file
      begin
        self.scan
      rescue
        raise Cigri::Error, "Unable to open config file #{config_file}!"
      end
    end
  
    # Scan (or re-scan) the configuration file and return the number of variables
    def scan
      @conf = {}
      file = File.new(@config_file, 'r')
      file.each do |line|
        a = line.scan(/^\s*([^#=\s]+)\s*=\s*"([^#]*)"/)
        key, val = a[0]
        @conf[key] = val if key
      end
      return @conf.length
    end  
 
    # Return true if the given configuration variable (key) exists
    def exists?(key)
      @conf.has_key?(key)
    end
 
    # Return the value of the given configuration variable
    def get(key)
      @conf[key]
    end
  end 
end
