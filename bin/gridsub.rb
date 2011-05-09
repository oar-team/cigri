#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../..', 'lib'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))
$LOAD_PATH.unshift("#{ENV["CIGRIDIR"]}/lib")

require 'cigri'
require 'jdl-parser'

abort("Usage: #{File.basename(__FILE__)} <JDL_FILE>") unless ARGV.length == 1

filename = ARGV[0]

abort("JDL file \"#{filename}\" not readable. Aborting") unless File.readable?(filename)

db_connect() do |dbh|
  id=Cigri::JDLParser.save(dbh, File.read(filename), 'Username')
  puts "Campaign ##{id} submited" if id
end

