#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../..', 'lib'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))

require 'cigri'
require 'jdl-parser'

abort("Usage: #{__FILE__} JDL_FILE") unless ARGV.length == 1

filename = ARGV[0]

abort("JDL file \"#{filename}\" not readable. Aborting") unless File.readable?(filename)

db_connect() do |dbh|
  p Cigri::JDLParser.save(dbh, File.read(filename))  
end

