# frozen_string_literal: true

require "socket"

class NatsServerControl
  BIN_PATH = File.expand_path(File.join(__dir__, "../../scripts/nats-server"))

  attr_reader :was_running
  alias_method :was_running?, :was_running

  class << self
    def init_with_config(config_file)
      config = File.open(config_file) { |f| YAML.safe_load(f) }
      uri = if (auth = config["authorization"])
        "nats://#{auth["user"]}:#{auth["password"]}@#{config["net"]}:#{config["port"]}"
      else
        "nats://#{config["net"]}:#{config["port"]}"
      end
      NatsServerControl.new(uri, config["pid_file"], "-c #{config_file}")
    end

    def init_with_config_from_string(config_string, config = {})
      puts config_string if debug?
      config_file = Tempfile.new(["nats-cluster-tests", ".conf"])
      File.open(config_file.path, "w") do |f|
        f.puts(config_string)
      end

      uri = if (auth = config["authorization"])
        "nats://#{auth["user"]}:#{auth["password"]}@#{config["host"]}:#{config["port"]}"
      else
        "nats://#{config["host"]}:#{config["port"]}"
      end

      NatsServerControl.new(uri, config["pid_file"], "-c #{config_file.path}", config_file)
    end

    def debug?
      %w[1 true t].include?(ENV["DEBUG_NATS_TEST"])
    end
  end

  attr_reader :uri

  def initialize(uri = "nats://127.0.0.1:4222", pid_file = "/tmp/test-nats.pid", flags = nil, config_file = nil)
    @uri = uri.is_a?(URI) ? uri : URI.parse(uri)
    @pid_file = pid_file
    @flags = flags
    @config_file = config_file
  end

  def debug?
    self.class.debug?
  end

  def server_pid
    @pid ||= File.read(@pid_file).chomp.to_i
  end

  def server_mem_mb
    server_status = `ps axo pid=,rss= | grep #{server_pid}`
    parts = server_status.lstrip.split(/\s+/)
    parts[1].to_i / 1024
  end

  def start_server(wait_for_server = true)
    if server_running? @uri
      @was_running = true
      return 0
    end
    @pid = nil

    args = "-p #{@uri.port} -P #{@pid_file}"

    if @uri.user && !@uri.password
      args += " --auth #{@uri.user}"
    else
      args += " --user #{@uri.user}" if @uri.user
      args += " --pass #{@uri.password}" if @uri.password
    end
    args += " #{@flags}" if @flags

    if debug?
      system("#{BIN_PATH} #{args} -DV &")
    else
      system("#{BIN_PATH} #{args} 2> /dev/null &")
    end
    exitstatus = $?.exitstatus
    wait_for_server(@uri, 10) if wait_for_server
    exitstatus
  end

  def kill_server
    if FileTest.exist? @pid_file
      `kill -TERM #{server_pid} 2> /dev/null`
      `rm #{@pid_file} 2> /dev/null`
      sleep(0.2)
      @pid = nil
    end
  end

  def wait_for_server(uri, max_wait = 5) # :nodoc:
    wait = max_wait.to_f
    loop do
      return if server_running?(uri)
      sleep(0.1)
      wait -= 0.1

      raise "NATS Server did not start in #{max_wait} seconds" if wait <= 0
    end
  end

  def server_running?(uri) # :nodoc:
    s = TCPSocket.new(uri.host, uri.port, nil, nil, connect_timeout: 0.5)
    true
  rescue => e
    puts "Server is not available: #{e}" if debug?
    false
  ensure
    s&.close
  end
end
