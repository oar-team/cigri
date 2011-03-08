#!/usr/bin/env ruby

require 'optparse'

options = {:dryrun => ''}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: psql_init.rb [options] ..."
  
  opts.on( '-d', '--database DATABASE', 'name of the CiGri database' ) do |database|
    options[:database] = database
  end
  
  opts.on( '-n', '--dryrun', 'prints all the commands but does not execute them' ) do
    options[:dryrun] = 'echo '
  end
  
    opts.on( '-p', '--password PASSWORD', 'password for user with full rights on the CiGri database' ) do |password|
    options[:password] = password
  end
  
  opts.on( '-s', '--sql SQL', 'SQL file to initialize the cigri database' ) do |sql|
    options[:sql] = sql
  end
  
  opts.on( '-u', '--user USER', 'login for user with full rights on the CiGri database' ) do |user|
    options[:user] = user
  end
  
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

begin
  optparse.parse!(ARGV)
rescue OptionParser::ParseError => e
  $stderr.puts e
  $stderr.puts "\n" + optparse.to_s
  exit 1
end

default = {:database => 'cigri',:user => 'cigri', :password => 'cigri',
           :sql => "./psql_structure.sql"}
questions = {
  :database => "Enter the name for the cigri database (default: #{default[:database]}): ",
  :user     => "Enter the username of the cigri user (default: #{default[:user]}): ",
  :password => "Enter the password of the cigri user (default: #{default[:password]}): ",
  :sql      => "Enter the SQL file to initialize the tables (default: #{default[:sql]}: )"
}

#force order using a list
[:database, :user, :password, :sql].each do |field|
  unless options[field]
    begin
      continue = false
      print questions[field]
      input = gets.chomp
      #white spaces are not permitted
      if input =~ /\s+/
        continue = true
        puts 'Spaces are not allowed, try again.'
        next
      end
      options[field] = input.empty? ? default[field] : input
    end while continue
    puts "Using: \'#{options[field]}\'"
  end
end

abort "[ERROR] #{options[:sql]} not readable, aborting." unless File.readable?(options[:sql])

BASE_CMD = "#{options[:dryrun]}sudo -u postgres psql -q -c "

puts 'Executing commands:'
system("#{BASE_CMD} \"CREATE DATABASE #{options[:database]}\"")
system("#{BASE_CMD} \"CREATE ROLE #{options[:user]} LOGIN PASSWORD \'#{options[:password]}\'\"")
cmd = "#{options[:dryrun]}psql -q -U #{options[:user]} -h 127.0.0.1 -d #{options[:database]} -f #{options[:sql]}"
system(cmd)
abort "[ERROR] Unable to execute: #{cmd}" unless $?.success?

puts "\nTERMINTATED"
