require 'openssl'

module Itamae
  module Client
    class PayloadValidator
      class InvalidSignatureError < StandardError; end
      class InvalidFormatError < StandardError; end

      def initialize(secrets)
        @secrets = secrets
      end

      def validate!(payload)
        match = payload.match(/\A(.+)\|([0-f]+)\z/)
        unless match
          raise InvalidFormatError, "Payload data should be like 'JSON|SIGNATURE' (#{payload})"
        end

        body = match[1]
        signature = match[2]

        valid = @secrets.any? do |secret|
          OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, body) == signature
        end

        unless valid
          raise InvalidSignatureError
        end
      end
    end
  end
end
