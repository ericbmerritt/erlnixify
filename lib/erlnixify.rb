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
      begin
        case @opts.command
        when "start"
          options = @opts.options[:start]
        when "startdeamon"
          options = @opts.options[:startdeamon]
        when "stop"
          options = @opts.options[:stop]
        else
          options = @opts.options[:start]
        end
      rescue Erlnixify::NodeError
        exit 127
      end

      if options[:version]
        puts Erlnixify::VERSION
        exit 0
      end

      if not options[:command]
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
      puts "-->#{@opts.command}"
      begin
        case @opts.command
        when "start"
          @node.start
        when "startdeamon"
          @node.start_deamon
          exit 0
        when "stop"
          @node.stop
        else
          @node.start
        end
      rescue Erlnixify::NodeError
        exit 127
      end
    end
  end
end
