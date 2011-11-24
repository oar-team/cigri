require 'spec_helper'
require 'cigri-exception'
require 'cigri-logger'

describe 'Error' do
  msg = 'Some error message for testing purposes'
  [Cigri::Error, Cigri::NotFound, Cigri::Unauthorized, Cigri::ParseError].each do |errorclass|
    it "should create an error of type #{errorclass.to_s}" do
      begin
        raise errorclass.new(msg)
      rescue Exception => e
        e.message.should be msg
        e.class.should be errorclass
        e.class.ancestors.include?(StandardError).should be true
        e.class.ancestors.include?(Cigri::Error).should be true
      end
    end

    it "should create an error of type #{errorclass.to_s} and log it" do
      logfile = '/tmp/rspec_test_errors'
      logger = Cigri::Logger.new('RSPEC Error testing', logfile)
      begin
        raise errorclass.new(msg, logger)
      rescue Exception => e
        e.message.should be msg
        e.class.should be errorclass
        e.class.ancestors.include?(StandardError).should be true
        e.class.ancestors.include?(Cigri::Error).should be true
        logged_data = File.readlines(logfile)
        logged_data.length.should be 2
        logged_data[1].include?(msg).should be true
        logged_data[1].include?('Exception raised').should be true
        logged_data[1].include?('RSPEC Error testing').should be true
      ensure
        File.delete(logfile)
      end
    end
  end
end