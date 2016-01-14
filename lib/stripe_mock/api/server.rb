module StripeMock

  @default_server_pid_path = './stripe-mock-server.pid'
  @default_server_log_path = './stripe-mock-server.log'

  class << self
    attr_writer :default_server_pid_path, :default_server_log_path

    ["pid", "log"].each do |config_type|
      define_method("default_server_#{config_type}_path") do
        instance_variable_get("@default_server_#{config_type}_path") || "./stripe-mock-server.#{config_type}"
      end
    end

    def spawn_server(opts={})
      pid_path = opts[:pid_path] || default_server_pid_path
      log_path = opts[:log_path] || default_server_log_path

      argv_backup = ARGV.dup
      ARGV.clear

      Dante::Runner.new('stripe-mock-server').execute(
        :daemonize => true, :pid_path => pid_path, :log_path => log_path
      ){
        StripeMock::Server.start_new(opts)
      }
      argv_backup.each do |arg|
        ARGV << arg
      end

      at_exit { kill_server(pid_path) }
    end

    def kill_server(pid_path=nil)
      puts "Killing server at #{pid_path}"
      path = pid_path || default_server_pid_path
      
      argv_backup = ARGV.dup
      ARGV.clear

      Dante::Runner.new('stripe-mock-server').execute(:kill => true, :pid_path => path)
      
      argv_backup.each do |arg|
        ARGV << arg
      end
    end
  end
end
