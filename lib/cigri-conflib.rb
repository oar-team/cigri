#!/usr/bin/ruby -w
#
# Cigri configuration library
#
# Usage example:
#
#$LOAD_PATH << './lib'
#require 'cigri-conflib'
#config=Cigri::Conf.new
#puts config.get("INSTALL_PATH")
#
#

require 'cigri-logger'

module Cigri

  if ENV['CIGRICONFDIR'] && File.exists?("#{ENV['CIGRICONFDIR']}/cigri.conf")
  then
    CONFIG_FILE="#{ENV['CIGRICONFDIR']}/cigri.conf"
  elsif ENV['CIGRIDIR'] && File.exists?("#{ENV['CIGRIDIR']}/cigri.conf")
    CONFIG_FILE="#{ENV['CIGRIDIR']}/cigri.conf"
  elsif File.exists?("./cigri.conf")
    CONFIG_FILE="./cigri.conf"
  else
    CONFIG_FILE="/etc/cigri.conf"
  end
  
  class Conf
    attr_reader :conf
    attr_accessor :config_file
  
    def initialize(config_file = CONFIG_FILE)
      @logger = Cigri::Logger.new('Conflib', STDOUT)
      begin
        @file=File.new(config_file,"r")
        self.scan
      rescue
        @logger.error("unable to open config file #{config_file}!")
      end
    end
  
    def scan
      @conf={}
      @file.each do |line|
        a=line.scan(/^\s*([^#=\s]+)\s*=\s*"([^#]*)"/)
        key,val=a[0]
        @conf[key]=val if key
      end
    end  
  
    def get(key)
      if @conf.has_key?(key)
        return @conf[key]
      else
        @logger.error("Conf: no key #{key}")
      end
    end
  end 
end
