require 'rspec'
require 'cigri-conflib'

Cigri.conf.conf['LOG_FILE'] = '/dev/null'
ENV['CIGRIDIR'] = File.expand_path(File.dirname(__FILE__))
