require 'rspec'

@log = Cigri.conf.get('LOG_FILE')
Cigri.conf.conf['LOG_FILE'] = '/dev/null'

Rspec.configure do |config|
  config.before(:all) do
    @log = Cigri.conf.get('LOG_FILE')
    Cigri.conf.conf['LOG_FILE'] = '/dev/null'
  end
  
  config.after(:all) do
    Cigri.conf.conf['LOG_FILE'] = @log
  end
end
