require 'rubygems'
require 'rspec'
require 'cigri-conflib'

Cigri.conf.conf['LOG_FILE'] = '/dev/null'
ENV['CIGRIDIR'] = File.expand_path(File.dirname(__FILE__))

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end

