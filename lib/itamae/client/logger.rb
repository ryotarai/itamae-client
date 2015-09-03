require "itamae/client/logger/stdout"

module Itamae
  module Client
    module Logger
      def self.class_from_type(type)
        self.const_get(type.capitalize)
      end
    end
  end
end
