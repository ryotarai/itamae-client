require "itamae/client/cli"
require "itamae/client/consul"
require "itamae/client/downloader"
require "itamae/client/logger"
require "itamae/client/multiplexer"
require "itamae/client/payload_validator"
require "itamae/client/runner"
require "itamae/client/version"

require "logger"

module Itamae
  module Client
    class << self
      attr_accessor :logger

      def reset_logger
        @logger ||= Multiplexer.new(::Logger.new($stdout))
      end
    end

    reset_logger
  end
end
