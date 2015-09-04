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
      method_option :execution_id, type: :string
      def apply(recipe_uri)
        load_config

        @execution_id = options[:execution_id] || Time.now.to_i.to_s
        setup_loggers

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
        load_config

        unless @config.secrets
          puts "Please set 'secrets' value in config file"
          abort
        end

        watcher = Consul::EventWatcher.new(@config.consul_url, @config.consul_event_name, @config.consul_index_file)
        watcher.watch do |event|
          begin
            PayloadValidator.new(@config.secrets).validate!(event.payload)
            data = JSON.parse(event.payload.match(/\A(.+)\|/)[1])

            @execution_id = data.fetch('execution_id')
            setup_loggers

            if Time.now - Time.parse(data.fetch('time')) > 60
              raise "The event is too old"
            end

            lock(!data['dry_run'] && @config.consul_lock_limit) do
              runner = Runner.new(
                dry_run: data['dry_run'],
                bootstrap_file: data['bootstrap_file'] || @config.bootstrap_file,
                node_json: @config.node_json,
              )
              runner.run(data.fetch('recipe_uri'))
            end
          rescue => err
            Itamae::Client.logger.error "#{err}\n#{err.backtrace.join("\n")}"
          end
        end
      end

      private

      def load_config
        @config = Itamae::Client::Config.new
        @config.load_yaml(options[:config]) if options[:config]
        @config.validate!
      end

      def setup_loggers
        loggers = @config.loggers.map do |logger_def|
          klass = Itamae::Client::Logger.class_from_type(logger_def.delete("type"))
          klass.new(logger_def.merge(execution_id: @execution_id))
        end
        Itamae::Client.logger = Multiplexer.new(*loggers)
      end

      def lock(lock_needed)
        if lock_needed
          lock = Consul::Lock.new(@config.consul_lock_prefix, @config.consul_lock_limit)
          Itamae::Client.logger.info "Waiting for obtaining lock"

          lock.with_lock do
            Itamae::Client.logger.info "Lock obtained"
            yield
          end
        else
          yield
        end
      end
    end
  end
end
