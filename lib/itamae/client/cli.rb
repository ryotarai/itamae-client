require 'thor'
require 'itamae/client/config'

module Itamae
  module Client
    class CLI < Thor
      def self.define_run_method_options
        method_option :config, type: :string
      end

      desc 'version', 'show version'
      def version
        puts "v#{VERSION}"
      end

      desc 'apply RECIPE_URI', 'run Itamae'
      define_run_method_options
      method_option :dry_run, type: :boolean, default: false
      def apply(recipe_uri)
        setup

        runner = Runner.new(
          dry_run: options[:dry_run],
          bootstrap_file: @config.bootstrap_file,
          node_json: @config.node_json,
        )
        runner.run(recipe_uri)
      end

      desc 'watch-consul', 'watch Consul events'
      define_run_method_options
      def watch_consul
        setup

        unless @config.secrets
          puts "Please set 'secrets' value in config file"
          abort
        end

        watcher = Consul::EventWatcher.new(@config.consul_url, @config.consul_index_file)
        watcher.watch do |event|
          begin
            PayloadValidator.new(@config.secrets).validate!(event.payload)
            data = JSON.parse(event.payload.match(/\A(.+)\|/)[1])

            if Time.now - Time.parse(data.fetch('time')) > 60
              raise "The event is too old"
            end

            runner = Runner.new(
              dry_run: data['dry_run'],
              bootstrap_file: data['bootstrap_file'] || @config.bootstrap_file,
              node_json: @config.node_json,
            )
            runner.run(data.fetch('recipe_uri'))
          rescue => err
            Itamae::Client.logger.error "#{err}\n#{err.backtrace.join("\n")}"
          end
        end
      end

      private

      def setup
        Itamae::Client.logger.debug "Starting"
        load_config
        setup_loggers
        Itamae::Client.logger.debug "Setting up done"
      end

      def load_config
        @config = Itamae::Client::Config.new
        @config.load_yaml(options[:config]) if options[:config]
        @config.validate!
      end

      def setup_loggers
        loggers = @config.loggers.map do |logger_def|
          klass = Itamae::Client::Logger.class_from_type(logger_def.delete("type"))
          klass.new(logger_def)
        end
        Itamae::Client.logger = Multiplexer.new(*loggers)
      end

      # desc 'consul-watch', 'watch Consul events'
      # define_run_method_options
      # method_option :index_file, type: :string, default: "/tmp/itamae-client-consul-index"
      # method_option :lock_prefix, type: :string, default: "itamae-client"
      # method_option :lock_limit, type: :numeric
      # def consul_watch
      #   prepare_client
      #   watcher = Consul::EventWatcher.new("http://localhost:8500", options[:index_file])
      #
      #   watcher.watch do |event|
      #     begin
      #       Itamae::Client.logger.debug "got event: #{event}"
      #
      #       execution_id = event.payload.fetch('execution_id')
      #       execution = @client.execution(execution_id)
      #
      #       if !execution.is_dry_run && options[:lock_limit]
      #         lock = Consul::Lock.new(options[:lock_prefix], options[:lock_limit])
      #         Itamae::Client.logger.info "waiting for obtaining lock"
      #
      #         lock.with_lock do
      #           Itamae::Client.logger.info "lock obtained"
      #           execute(execution_id)
      #         end
      #       else
      #         execute(execution_id)
      #       end
      #     rescue => err
      #       Itamae::Client.logger.error "#{err}\n#{err.backtrace.join("\n")}"
      #       execution.host_execution.mark_as('aborted') if execution
      #     end
      #   end
      # end
      #
      # private
      #
      # def prepare_client
      #   @client = APIClient.new(options[:server_url])
      # end
      #
      # def execute(execution_id)
      #   execution = @client.execution(execution_id)
      #   revision = execution.revision
      #   host_execution = execution.host_execution
      #
      #   Itamae::Client.logger.debug "execution: #{execution}"
      #   Itamae::Client.logger.debug "revision: #{revision}"
      #   Itamae::Client.logger.debug "host execution: #{host_execution}"
      #
      #   unless execution.in_progress?
      #     Itamae::Client.logger.error "execution ##{execution.id} is not in progress"
      #     return
      #   end
      #
      #   if !execution.is_dry_run && !revision.active?
      #     Itamae::Client.logger.error "actual run can be done only against an active revision"
      #     return
      #   end
      #
      #   unless host_execution
      #     Itamae::Client.logger.error "no HostExecution found"
      #     return
      #   end
      #
      #   Runner.new(revision, execution, host_execution, options).run
      # end
    end
  end
end
