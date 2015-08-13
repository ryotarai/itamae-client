require 'faraday'
require 'socket'
require 'shellwords'
require 'open3'

module Itamae
  module Client
    class Runner
      ITAMAE_BIN = 'itamae'
      BOOTSTRAP_RECIPE_FILE = 'bootstrap.rb'
      CONSUL_LOCK_PREFIX = 'itamae'

      class Error < StandardError; end

      def initialize(revision, execution, host_execution, options)
        @revision = revision
        @execution = execution
        @host_execution = host_execution
        @options = options

        prepare
      end

      def run
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

          args = ['--log-level', 'debug']
          args << '--node-json' << 'node.json' if node_attribute
          args << "--dry-run" if @execution.is_dry_run
          args << BOOTSTRAP_RECIPE_FILE

          execute_itamae(*args)
        end
        @host_execution.mark_as('completed')
      rescue
        @host_execution.mark_as('aborted')
        raise
      end

      private

      def execute_itamae(*args)
        io = MultiIO.new($stdout, @host_execution.create_writer)

        Bundler.with_clean_env do
          cmd = [ITAMAE_BIN, "local"] + args
          Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
            stdin.close
            readers = [stdout, stderr]
            while readers.any?
              ready = IO.select(readers, [], readers)
              ready[0].each do |fd|
                if fd.eof?
                  fd.close
                  readers.delete(fd)
                else
                  io.write(fd.readpartial(1024))
                end
              end
            end

            exitstatus = wait_thr.value.exitstatus
            io.write("Itamae exited with #{exitstatus}\n")

            unless exitstatus == 0
              raise "Itamae exited with #{exitstatus}"
            end
          end
        end
      end

      def in_tmpdir
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            puts "(in #{tmpdir})"
            yield
          end
        end
      end

      def prepare
        register_trap

        @signal_handlers << proc do
          @host_execution.mark_as('aborted')
        end
      end

      def system_or_abort(*args)
        options = {}
        if args.last.is_a?(Hash)
          options = args.pop
        end

        puts "executing: #{args.shelljoin}"
        Bundler.with_clean_env do
          unless system(*args, options)
            raise "command failed."
          end
        end
      end

      def register_trap
        @signal_handlers = []
        [:INT, :TERM].each do |sig|
          Signal.trap(sig) do
            @signal_handlers.reverse_each do |h|
              h.call
            end

            abort
          end
        end
      end
    end
  end
end
