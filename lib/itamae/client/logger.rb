require "itamae/client/logger/stdout"
require "itamae/client/logger/syslog"
require "itamae/client/logger/file"

module Itamae
  module Client
    module Logger
      def self.class_from_type(type)
        self.const_get(type.capitalize)
      end
    end
  end
end
