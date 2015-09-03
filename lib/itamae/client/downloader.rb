require 'uri'
require 'fileutils'
require 'aws-sdk'

module Itamae
  module Client
    class Downloader
      def download(src, dst)
        src_uri = URI.parse(src)
        case src_uri.scheme
        when "s3"
          download_s3(src_uri, dst)
        when "http", "https"
          download_http(src_uri, dst)
        when nil
          download_local(src_uri, dst)
        else
          raise "Unknown scheme: #{src_uri.scheme}"
        end
      end

      private

      def download_local(src, dst)
        FileUtils.cp(src.path, dst)
      end

      def download_s3(src, dst)
        s3 = Aws::S3::Client.new

        key = src.path.gsub(%r{\A/}, '')
        s3.get_object(
          response_target: dst,
          bucket: src.host,
          key: key,
        )
      end

      def download_http(src, dst)
        raise NotImplementedError
      end
    end
  end
end
