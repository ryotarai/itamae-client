require "syslog/logger"

module Itamae
  module Client
    module Logger
      class Syslog < ::Syslog::Logger
        def initialize(options)
          program_name = options['program_name'] || 'itamae-client'
          facility = options['facility']
          super(program_name, facility)
        end
      end
    end
  end
end
