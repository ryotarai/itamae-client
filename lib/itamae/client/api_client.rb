require 'faraday'
require 'socket'

module Itamae
  module Client
    class APIClient
      class Error < StandardError; end

      module Response
        class Execution < Struct.new(:client, :id, :revision_id, :is_dry_run, :status)
          def revision
            self.client.revision(revision_id)
          end

          def host_execution
            self.client.host_executions(execution_id: self.id).first
          end

          def in_progress?
            self.status == "in_progress"
          end
        end

        class Revision < Struct.new(:client, :id, :file_url, :active?)
          def file_url
            URI.join(client.server_url, super).to_s
          end
        end

        class HostExecution < Struct.new(:client, :id, :status)
          def create_writer
            HostExecutionWriter.new(self)
          end

          def mark_as(status)
            self.client.update_host_execution(self.id, status: status)
          end
        end
      end

      class HostExecutionWriter
        def initialize(host_execution)
          @endpoint = "host_executions/#{host_execution.id}/append_log.json"
          @conn = Faraday.new(url: host_execution.client.server_url) do |f|
            f.adapter Faraday.default_adapter
          end
        end

        def write(data)
          res = @conn.put(@endpoint) do |req|
            req.body = data
          end

          unless 200 <= res.status && res.status < 300
            raise "sending host_execution failed"
          end
        end
      end

      attr_accessor :server_url

      def initialize(server_url)
        @server_url = server_url
        @conn ||= Faraday.new(url: @server_url) do |faraday|
          faraday.request :url_encoded
          faraday.adapter Faraday.default_adapter
        end
      end

      def execution(id)
        res = get("/executions/#{id}.json")
        create_model_from_response(Response::Execution, res)
      end

      def create_execution(params)
        res = post("/executions.json", execution: params)
        create_model_from_response(Response::Execution, res)
      end

      def revision(id)
        res = get("/revisions/#{id}.json")
        create_model_from_response(Response::Revision, res)
      end

      def host_executions(criteria = {})
        criteria = {host: Socket.gethostname}.merge(criteria)

        get("/host_executions.json", criteria).map do |res|
          create_model_from_response(Response::HostExecution, res)
        end
      end

      def create_host_execution(params)
        res = post("/host_executions.json", host_execution: params)
        create_model_from_response(Response::HostExecution, res)
      end

      def update_host_execution(id, data = {})
        patch("/host_executions/#{id}.json", host_execution: data)
      end

      private

      def create_model_from_response(klass, res)
        klass.new.tap do |model|
          model.client = self
          model.members.each do |f|
            next if f == :client
            model[f] = res.fetch(f.to_s)
          end
        end
      end

      def http_request(method, valid_status, *args)
        res = @conn.public_send(method, *args)

        unless valid_status.include?(res.status)
          raise Error, "invalid API response (#{res.status}: #{res.body})"
        end

        JSON.parse(res.body)
      end

      def get(*args)
        http_request(:get, 200...300, *args)
      end

      def post(*args)
        http_request(:post, 200...300, *args)
      end

      def patch(*args)
        http_request(:patch, 200...300, *args)
      end
    end
  end
end
