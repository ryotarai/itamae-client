require "itamae/client/api_client"
require "itamae/client/cli"
require "itamae/client/consul_event"
require "itamae/client/multi_io"
require "itamae/client/runner"
require "itamae/client/version"

require "logger"

module Itamae
  module Client
    @logger ||= ::Logger.new($stdout)

    class << self
      attr_accessor :logger
    end
  end
end
