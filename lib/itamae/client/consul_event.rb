require 'json'
require 'base64'

module Itamae
  module Client
    class ConsulEvent < Struct.new(:payload)
      def self.all
        @all ||= JSON.parse($stdin.read).map do |e|
          self.new.tap do |event|
            event.payload = JSON.parse(Base64.decode64(e.fetch('Payload')))
          end
        end
      end

      def self.last
        all.last
      end
    end
  end
end
