require 'thor'

module Itamae
  module Client
    class CLI < Thor
      def self.define_run_method_options
        method_option :server_url, type: :string, required: true
        method_option :node_attribute, type: :string
      end

      desc 'version', 'show version'
      def version
        puts "v#{VERSION}"
      end

      desc 'apply', 'run Itamae'
      define_run_method_options
      method_option :revision, type: :string, required: true
      method_option :dry_run, type: :boolean, default: false
      def apply
        prepare_client
        revision = @client.revision(options[:revision])
        execution = @client.create_execution(revision_id: revision.id, is_dry_run: options[:dry_run])
        host_execution = @client.create_host_execution(
          execution_id: execution.id,
          status: "pending",
        )

        Runner.new(revision, execution, host_execution, options).run
      end

      desc 'consul-watch', 'watch Consul events'
      define_run_method_options
      method_option :index_file, type: :string, default: "/tmp/itamae-client-consul-index"
      method_option :lock_prefix, type: :string, default: "itamae-client"
      method_option :lock_limit, type: :numeric
      def consul_watch
        prepare_client
        watcher = Consul::EventWatcher.new("http://localhost:8500", options[:index_file])

        watcher.watch do |event|
          begin
            Itamae::Client.logger.debug "got event: #{event}"

            execution_id = event.payload.fetch('execution_id')
            execution = @client.execution(execution_id)

            if !execution.is_dry_run && options[:lock_limit]
              lock = Consul::Lock.new(options[:lock_prefix], options[:lock_limit])
              Itamae::Client.logger.info "waiting for obtaining lock"

              lock.with_lock do
                Itamae::Client.logger.info "lock obtained"
                execute(execution_id)
              end
            else
              execute(execution_id)
            end
          rescue => err
            Itamae::Client.logger.error "#{err}\n#{err.backtrace.join("\n")}"
            execution.host_execution.mark_as('aborted') if execution
          end
        end
      end

      private

      def prepare_client
        @client = APIClient.new(options[:server_url])
      end

      def execute(execution_id)
        execution = @client.execution(execution_id)
        revision = execution.revision
        host_execution = execution.host_execution

        Itamae::Client.logger.debug "execution: #{execution}"
        Itamae::Client.logger.debug "revision: #{revision}"
        Itamae::Client.logger.debug "host execution: #{host_execution}"

        unless execution.in_progress?
          Itamae::Client.logger.error "execution ##{execution.id} is not in progress"
          return
        end

        if !execution.is_dry_run && !revision.active?
          Itamae::Client.logger.error "actual run can be done only against an active revision"
          return
        end

        unless host_execution
          Itamae::Client.logger.error "no HostExecution found"
          return
        end

        Runner.new(revision, execution, host_execution, options).run
      end
    end
  end
end
