require "itamae/client/cli"
require "itamae/client/consul"
require "itamae/client/downloader"
require "itamae/client/logger"
require "itamae/client/multiplexer"
require "itamae/client/multi_io"
require "itamae/client/runner"
require "itamae/client/version"

require "logger"

module Itamae
  module Client
    @logger ||= Multiplexer.new(::Logger.new($stdout))

    class << self
      attr_accessor :logger
    end
  end
end
