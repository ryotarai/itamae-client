require 'json'
require 'base64'
require 'pathname'
require 'open3'
require 'timeout'
require 'faraday'

module Itamae
  module Client
    module Consul
      class Lock
        def initialize(prefix, limit)
          @prefix = prefix
          @limit = limit
        end

        def with_lock(timeout_sec = 24 * 60 * 60)
          # TODO: Reimplement with Consul HTTP API
          args = ["consul", "lock", "-n", @limit.to_s, @prefix, "echo START; sleep #{timeout_sec + 60}"]
          Itamae::Client.logger.debug args.shelljoin
          Open3.popen3(*args) do |stdin, stdout, stderr, wait_thr|
            begin
              line = stdout.readline
              unless line.chomp == "START"
                raise "failed to obtain a lock: #{line}"
              end

              lock_thread = Thread.start do
                wait_thr.join # blocking
                raise "lock is gone"
              end
              lock_thread.abort_on_exception = true

              yield
            ensure
              lock_thread.terminate if lock_thread
              Process.kill(:TERM, wait_thr[:pid]) if wait_thr.alive?
            end
          end
        end
      end

      class Event < Struct.new(:payload)
      end

      class EventWatcher
        def initialize(url, name, index_file)
          @url = url
          @name = name
          @index_file = Pathname.new(index_file)
        end

        def watch
          conn = Faraday.new(:url => @url) do |faraday|
            faraday.request  :url_encoded             # form-encode POST params
            # faraday.response :logger                  # log requests to STDOUT
            faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
          end

          unless @index_file.exist?
            res = conn.get("/v1/event/list")
            @index_file.write(res.headers["X-Consul-Index"])
          end

          while true
            begin
              Itamae::Client.logger.debug "waiting for a new event"
              res = conn.get do |req|
                req.url "/v1/event/list"
                req.params['name'] = @name
                req.params['index'] = @index_file.read
                req.options.timeout = 60 * 10 # 10 min
              end
            rescue Faraday::TimeoutError
              retry
            rescue Faraday::ConnectionFailed
              Itamae::Client.logger.warn "connection to Consul failed. will retry after 60 sec"
              sleep 60
              retry
            end

            if 200 <= res.status && res.status < 300
              @index_file.write(res.headers["X-Consul-Index"])

              event_hash = JSON.parse(res.body).last
              next unless event_hash

              Itamae::Client.logger.info "new event: #{event_hash["ID"]}"
              event = Event.new.tap do |e|
                e.payload = Base64.decode64(event_hash.fetch('Payload'))
              end

              yield(event)
            else
              # retry
              sleep 60
            end
          end
        end
      end
    end
  end
end
