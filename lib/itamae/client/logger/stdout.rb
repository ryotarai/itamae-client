require "logger"

module Itamae
  module Client
    module Logger
      class Stdout < ::Logger
        def initialize(options)
          super($stdout)
        end
      end
    end
  end
end
