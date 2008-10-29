#!/usr/bin/ruby -w
# Cigri configuration library

if ENV['CIGRIDIR']
then
  config_file="#{ENV['CIGRIDIR']}/cigri.conf"
else
  config_file="/etc/cigri.conf"
end


begin
  file=File.new(config_file,"r")
rescue
  puts "Unable to open config file #{config_file}!"
end

$conf={}
file.each do |line|
  a=line.scan(/^\s*([^#=\s]+)\s*=\s*"([^#]*)"/)
  key,val=a[0]
  $conf[key]=val if key
end

def get_conf(key)
  $conf[key]
end
