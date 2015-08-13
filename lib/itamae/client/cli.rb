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
        client = APIClient.new(@options[:server_url])

        revision = client.revision(@options[:revision])
        execution = client.create_execution(revision_id: revision.id, is_dry_run: @options[:dry_run])
        host_execution = client.create_host_execution(execution_id: execution.id, host: Socket.gethostbyname(Socket.gethostname).first)

        Runner.new(revision, execution, host_execution, options).run
      end

      desc 'consul', 'handle Consul events'
      define_run_method_options
      method_option :once, type: :boolean, default: true, desc: 'for debugging'
      def consul
        event = ConsulEvent.last

        unless event
          puts "no event"
          exit
        end

        client = APIClient.new(@options[:server_url])
        execution = client.execution(event.payload.fetch('execution_id'))
        revision = execution.revision
        host_execution = client.create_host_execution(execution_id: execution.id, host: Socket.gethostbyname(Socket.gethostname).first)

        Runner.new(revision, execution, host_execution, options).run
      end
    end
  end
end
