require "erlnixify/version"
require "erlnixify/opts"
require "erlnixify/settings"
require "erlnixify/node"

module Erlnixify

  # The main entry point for erlnixify
  class Main
    def self.main(args)
      @opts = Erlnixify::Opts.new(args)
      options = nil
      options = @opts.options[@opts.command]
      if options[:version]
        puts Erlnixify::VERSION
        exit 0
      end

      if ((@opts.command == "start" or
           @opts.command == "startdeamon") and not options[:command])
        puts "missing command option, this is required"
        puts @opts.opts.help
        exit 1
      end

      if not options[:name]
        puts "missing name option"
        puts @opts.opts.help
        exit 1
      end

      if not (options[:cookie] || options[:cookiefile])
        puts "missing both cookie and cookiefile options, at least one is required"
        puts @opts.opts.help
        exit 1
      end
      @settings = Erlnixify::Settings.new(options)
      @node = Erlnixify::Node.new(@settings)
      begin
        case @opts.command
        when :start
          @node.start
        when :startdaemon
          @node.start_daemon
          exit 0
        when :stop
          @node.stop
        when :status
          begin
            @node.status
          rescue Exception => msg
            puts "stopped", msg
            exit 127
          end
        else
          @node.start
        end
      rescue Erlnixify::NodeError
        exit 127
      end
    end
  end
end
