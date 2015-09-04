module Itamae
  module Client
    module Logger
      class CloudWatchLogs < ::Logger
        def initialize(options)
          super(IO.new(options))
        end

        class IO
          def initialize(options)
            execution_id = options.fetch(:execution_id)
            hostname = `hostname -f`

            @log_group = options.fetch('log_group')
            @log_stream = "#{execution_id}/#{hostname}"
            @events = []
            
            @client = create_client(options)

            create_stream
            start_sending
          end

          def write(body)
            @events << {time: Time.now, body: body}
          end

          def close
            @closed = true
          end

          private

          def create_stream
            @client.create_log_stream({
              log_group_name: @log_group,
              log_stream_name: @log_stream,
            })
          end

          def start_sending
            @thread = Thread.start do
              token = nil

              while true
                sleep 1

                events = @events
                @events = []

                unless events.empty?
                  log_events = events.map do |e|
                    {timestamp: (e[:time].to_f * 1000).to_i, message: e[:body]}
                  end

                  req = {
                    log_group_name: @log_group,
                    log_stream_name: @log_stream,
                    log_events: log_events,
                  }

                  if token
                    req[:sequence_token] = token
                  end

                  res = @client.put_log_events(req)
                  token = res.next_sequence_token
                end

                if @closed && @events.empty?
                  break
                end
              end
            end
            @thread.abort_on_exception = true

            at_exit do
              close
              @thread.join
            end
          end

          def create_client(options)
            client_opts = {}
            client_opts[:region] = options[:region] if options[:region]
            if options[:access_key_id] && options[:secret_access_key]
              client_opts[:credentials] = Aws::Credentials.new(
                options[:access_key_id], options[:secret_access_key])
            end

            Aws::CloudWatchLogs::Client.new(client_opts)
          end
        end
      end
    end
  end
end
