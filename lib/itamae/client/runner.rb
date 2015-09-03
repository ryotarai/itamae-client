require 'faraday'
require 'socket'
require 'shellwords'
require 'open3'
require 'itamae'

module Itamae
  module Client
    class Runner
      class Error < StandardError; end

      def initialize(options)
        @dry_run = options.fetch(:dry_run)
        @bootstrap_file = options.fetch(:bootstrap_file)
        @node_json = options.fetch(:node_json)
      end

      def run(recipe_uri)
        original_pwd = Dir.pwd
        in_tmpdir do |tmpdir|
          dst = File.join(tmpdir, "recipes-tar")
          Dir.chdir(original_pwd) do
            Downloader.new.download(recipe_uri, dst)
          end

          run_option = {
            dry_run: @dry_run,
          }

          if @node_json
            full_path = File.expand_path(@node_json, original_pwd)
            if File.executable?(full_path)
              system_or_abort(full_path, out: "node.json")
            else
              FileUtils.cp(full_path, 'node.json')
            end
            run_option[:node_json] = "node.json"
          end

          system_or_abort("tar", "xf", dst)

          Itamae::Runner.run([File.join(tmpdir, @bootstrap_file)], "local", run_option)
        end
      end

      # def initialize(revision, execution, host_execution, options)
      #   @revision = revision
      #   @execution = execution
      #   @host_execution = host_execution
      #   @options = options
      # end
      #
      # def run
      #   unless @host_execution.status == 'pending'
      #     raise "HostExecution ##{@host_execution.id} is not pending status"
      #   end
      #
      #   @host_execution.mark_as('in_progress')
      #
      #   working_dir = Dir.pwd
      #   in_tmpdir do
      #     if node_attribute = @options[:node_attribute]
      #       node_attribute = File.expand_path(node_attribute, working_dir)
      #       if File.executable?(node_attribute)
      #         system_or_abort(node_attribute, out: "node.json")
      #       else
      #         FileUtils.cp(node_attribute, 'node.json')
      #       end
      #     end
      #
      #     # download
      #     system_or_abort("wget", "-O", "recipes.tar", @revision.file_url)
      #     system_or_abort("tar", "xf", "recipes.tar")
      #
      #     Itamae::Logger.log_device = MultiIO.new($stdout, @host_execution.create_writer)
      #     Itamae::Runner.run([BOOTSTRAP_RECIPE_FILE], "local", {
      #       dry_run: @execution.is_dry_run,
      #     })
      #   end
      #   @host_execution.mark_as('completed')
      # rescue
      #   @host_execution.mark_as('aborted')
      #   raise
      # end
      #
      private

      def in_tmpdir
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            Itamae::Client.logger.debug "(in #{tmpdir})"
            yield(tmpdir)
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
