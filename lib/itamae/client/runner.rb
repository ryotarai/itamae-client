require 'faraday'
require 'socket'
require 'shellwords'
require 'open3'
require 'itamae'

module Itamae
  module Client
    class Runner
      ITAMAE_BIN = 'itamae'
      BOOTSTRAP_RECIPE_FILE = 'bootstrap.rb'

      class Error < StandardError; end

      def initialize(revision, execution, host_execution, options)
        @revision = revision
        @execution = execution
        @host_execution = host_execution
        @options = options
      end

      def run
        unless @host_execution.status == 'pending'
          raise "HostExecution ##{@host_execution.id} is not pending status"
        end

        @host_execution.mark_as('in_progress')

        working_dir = Dir.pwd
        in_tmpdir do
          if node_attribute = @options[:node_attribute]
            node_attribute = File.expand_path(node_attribute, working_dir)
            if File.executable?(node_attribute)
              system_or_abort(node_attribute, out: "node.json")
            else
              FileUtils.cp(node_attribute, 'node.json')
            end
          end

          # download
          system_or_abort("wget", "-O", "recipes.tar", @revision.file_url)
          system_or_abort("tar", "xf", "recipes.tar")

          Itamae::Logger.log_device = MultiIO.new($stdout, @host_execution.create_writer)
          Itamae::Runner.run([BOOTSTRAP_RECIPE_FILE], "local", {
            dry_run: @execution.is_dry_run,
          })
        end
        @host_execution.mark_as('completed')
      rescue
        @host_execution.mark_as('aborted')
        raise
      end

      private

      def in_tmpdir
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            Itamae::Client.logger.debug "(in #{tmpdir})"
            yield
          end
        end
      end

      def system_or_abort(*args)
        options = {}
        if args.last.is_a?(Hash)
          options = args.pop
        end

        Itamae::Client.logger.debug "executing: #{args.shelljoin}"
        Bundler.with_clean_env do
          unless system(*args, options)
            raise "command failed."
          end
        end
      end
    end
  end
end
