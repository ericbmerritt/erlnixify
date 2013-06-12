require 'logger'
require 'timeout'
require 'erlnixify/exceptions'

module Erlnixify
  COMMAND_WRAPPER = "%{erl_interface}/bin/erl_call -n %{fullnode} \
-c '%{cookie}' -a '%{cmd}'"

  SHUTDOWN_COMMAND = "init stop"

  BRUTAL_SHUTDOWN_COMMAND = "erlang halt 127"

  # The process class owns the Running erlang process. It knows how to
  # query it if its active, and kill it if something goes long. This
  # class is the guts of erlnixify
  class Node
    def initialize(settings)
      @settings = settings
      @command = @settings[:command] % settings.settings
      @check_command = self.interpolate_cmd(@settings[:check])
      @halt_command = self.interpolate_cmd(SHUTDOWN_COMMAND)
      @brutal_halt_command = self.interpolate_cmd(BRUTAL_SHUTDOWN_COMMAND)
      @checkregex = Regexp.new @settings[:checkregex]

      @log = Logger.new(STDOUT)
      @log.level = Logger::DEBUG

    end

    def start
      self.start_deamon

      Signal.trap("TERM") do
        # This is going to propagate to the running erlang
        # node. Unfortunately, there is no way to stop that that I
        # have found yet. Hopefully, in the near future we can resolve
        # that.
        raise NodeError, "SIGTERM recieved, shutting down"
      end

      Signal.trap("INT") do
        # This is going to propagate to the running erlang
        # node. Unfortunately, there is no way to stop that that I
        # have found yet. Hopefully, in the near future we can resolve
        # that.
        raise NodeError, "SIGINT recieved, shutting down"
      end

      at_exit { self.external_kill }

      @log.debug "waiting for #{@settings[:startuptimeout]} seconds for startup"
      sleep @settings[:startuptimeout]
      self.monitor
    end

    def start_deamon
      begin
        self.status
      rescue NodeError => msg
        return self.raw_start_deamon
      end
      raise NodeError, "Already started"
    end

    def raw_start_deamon
      @log.debug "starting daemon"
      env = {}
      env["HOME"] = @settings[:home] if @settings[:home]

      begin
        @log.debug "spawning command '#{@command}' with #{env}"
        @pid = Process.spawn(env, @command)
        Process.detach @pid
      rescue Errno::ENOENT
        @log.debug "Invalid command provided, raising error"
        raise NodeError, "Command does not exist"
      end

      @log.debug "waiting for #{@settings[:startuptimeout]} seconds for startup"
      sleep @settings[:startuptimeout]
      self.status
    end

    def monitor
      @log.debug "starting monitor of Pid #{@pid}"
      loop do
        if is_running?
          self.check
          sleep @settings[:checkinterval]
        else
          raise NodeError, "Node not running"
        end
        break if @stop
        @log.debug "Node responded correctly, continuing check"
      end
    end

    def check
      begin
        Timeout.timeout(@settings[:checktimeout]) do
          self.raw_check
        end
      rescue Timeout::Error
        self.halt_nicely
        raise NodeError, "Check command timeout occurred"
      end
    end

    def status
      begin
        Timeout.timeout(@settings[:checktimeout]) do
            self.raw_check
        end
      rescue Timeout::Error
        self.halt_nicely
        raise NodeError, "Check command timeout occurred"
      end
    end

    def raw_check
      @log.debug "#{@check_command} =~ #{@checkregex}"
      result = `#{@check_command}`
      @log.debug "result #{result}"
      if not (result =~ @checkregex)
        @log.info "invalid state"
        self.halt_nicely
        raise NodeError, "Node check failed"
      else
        @log.info "running"
      end
    end

    def is_running?
      @log.debug "Checking if Pid (#{@pid}) is running"
      if @pid
        begin
          Process.getpgid(@pid)
          true
        rescue Errno::ESRCH
          false
        end
      else
        false
      end
    end

    def stop
      @log.debug "Executing halt nicely: #{@halt_command}"
      `#{@halt_command}`
      if not $?
        sleep @settings[:checkinterval]
      else
        raise NodeError, "Got status #{$?}"
      end
    end

    def halt_nicely
      if self.is_running?
        @log.debug "Executing halt nicely: #{@halt_command}"
        `#{@halt_command}`
        sleep @settings[:checkinterval]
        self.halt_brutally
      end
    end

    def halt_brutally
      if self.is_running?
        @log.debug "Executing halt brutally: #{@brutal_halt_command}"
        `#{@brutal_halt_command}`
        sleep @settings[:checkinterval]
        self.external_kill
      end
    end

    def external_kill
      if self.is_running?
        @log.debug "Killing pid: #{@pid}"
        Process.kill("KILL", @pid) if @pid
      end
    end

    def interpolate_cmd(cmd)
      local_settings = @settings.settings.clone
      local_settings[:cmd] = cmd % local_settings
      COMMAND_WRAPPER % local_settings
    end
  end
end
