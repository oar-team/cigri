#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../..', 'lib'))

require 'cigri_jdl_parser'

abort ("Usage: #{__FILE__} JDL_FILE") unless ARGV.length == 1

filename = ARGV[0]

abort ("JDL file \"#{filename}\" not readable. Aborting") unless File.readable?(filename)


p Cigri::JDLParser.save(nil, File.read(filename))

