require "yaml"

module Itamae
  module Client
    class Config
      DEFAULT = {
        "bootstrap_file" => "bootstrap.rb",
        "loggers" => [
          {"type" => "stdout"},
        ],
        "consul_url" => "http://localhost:8500",
        "consul_event_name" => "itamae-client",
        "consul_index_file" => "/var/lib/itamae-client.consul.index",
        "consul_lock_prefix" => "itamae-client",
      }

      def initialize
        @hash = DEFAULT.dup
      end

      def load_yaml(path)
        @hash.merge!(YAML.load_file(path))
      end

      def validate!
      end

      %w!
        bootstrap_file
        consul_event_name
        consul_index_file
        consul_lock_limit
        consul_lock_prefix
        consul_url
        loggers
        node_json
        secrets
      !.each do |m|
        class_eval <<-EOC
          def #{m}
            @hash['#{m}']
          end
        EOC
      end
    end
  end
end
