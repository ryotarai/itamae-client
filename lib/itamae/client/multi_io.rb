module Itamae
  module Client
    class MultiIO
      def initialize(*ios)
        @ios = ios
      end

      def write(*args)
        @ios.each do |io|
          io.write(*args)
        end
      end

      def close(*args)
        @ios.each do |io|
          io.close(*args)
        end
      end
    end
  end
end

