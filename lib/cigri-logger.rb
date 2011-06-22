require 'logger'
require 'cigri-conflib'

module Cigri
  ##
  # Specific Logger for Cigri. 
  # Changes the ruby logger output and needs a progname
  ##
  class Logger < Logger
    ##
    # Create a new Logger: logger = Logger.new('module', STDOUT [, shift_age, shift_size])
    # Params:
    #   - progname: Name of the module you want to log
    #   - logdev: location of the file to save the log (can be STDOUT or STDERR). Default = STDOUT
    ##
    def initialize(progname, logdev = 'STDOUT')
      config = Cigri.conf
      level = config.get('LOG_LEVEL') if config.exists?('LOG_LEVEL')
      @logdev_name=logdev
      logdev = STDOUT if logdev.eql? 'STDOUT'
      logdev = STDERR if logdev.eql? 'STDERR'
      super(logdev)
      self.progname = progname
      self.level = Logger.const_get(level)
    end

    private

    # Formatting mods

    def format_message(severity, datetime, progname, msg)
      date = datetime.strftime('%Y-%m-%d %H:%M:%S.') << "%d" % datetime.usec
      # Less info and colored on the console
      if @logdev_name == 'STDOUT' or @logdev_name == 'STDERR'
        date = datetime.strftime('%Y-%m-%d %H:%M:%S')
        log_str = "[#{date}][#{severity[0...1]}][#{progname}] #{color_msg(msg, severity, progname)}\n"
      else
        date = datetime.strftime('%Y-%m-%d %H:%M:%S.') << "%d" % datetime.usec
        log_str = "[#{date}][#{severity[0...1]}][#{$$}][#{progname}] #{msg}\n"
      end
    end

    def color_msg msg, severity, progname 
      # Background color depending on severity
      back_color = severity[0...1] == 'E' ? '41' : '40' # Red for errors, black otherwize
      # Text color depending on the progname
      case 
        when progname == "ALMIGHTY"
          fore_color = 32
        when progname.match(/RUNNER/)
          fore_color = 34
        when progname.match(/SCHEDULER/)
          fore_color = 36
        else
          fore_color = 30
      end
      "\033[1;#{back_color}m\033[#{fore_color}m#{msg}\033[0m"
    end

  end
end
