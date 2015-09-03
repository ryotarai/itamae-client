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
        "consul_index_file" => "/var/lib/itamae-client.consul.index"
      }

      def initialize
        @hash = DEFAULT.dup
      end

      def load_yaml(path)
        @hash.merge!(YAML.load_file(path))
      end

      def validate!
      end

      %w!bootstrap_file loggers node_json consul_url consul_index_file secrets!.each do |m|
        class_eval <<-EOC
          def #{m}
            @hash['#{m}']
          end
        EOC
      end
    end
  end
end
