#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.expand_path(File.dirname(__FILE__)),'../', 'lib'))
$LOAD_PATH.unshift(File.join(File.expand_path(File.dirname(__FILE__))))
$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'

db_connect() do |dbh|
  get_running_campaigns(dbh).each do |id|
    delete_campaign(dbh, 'root', id)
  end
end
