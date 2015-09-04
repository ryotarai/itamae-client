require "itamae/client/logger/stdout"
require "itamae/client/logger/syslog"
require "itamae/client/logger/file"
require "itamae/client/logger/cloud_watch_logs"

module Itamae
  module Client
    module Logger
      def self.class_from_type(type)
        name = type.split('_').map(&:capitalize).join
        self.const_get(name)
      end
    end
  end
end
