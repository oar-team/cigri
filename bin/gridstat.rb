#!/usr/bin/ruby -w

$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'
require 'net/http'
require 'json'
require 'pp'

campaigns = JSON.parse(Net::HTTP.get('localhost', '/campaigns', 9292))

campaigns['items'].each do |campaign|
  pp campaign
end
