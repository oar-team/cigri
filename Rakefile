require 'rubygems'
require 'rspec/core/rake_task'
require 'rake/rdoctask'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = ["-c"]#
end

Rake::RDocTask.new do |rdoc|
  require 'cigri'
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "Cigri #{Cigri::VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.include('modules/**/*.rb')
end
