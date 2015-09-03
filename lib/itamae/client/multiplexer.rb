module Itamae
  module Client
    class Multiplexer
      def initialize(*delegate_to)
        @delegate_to = delegate_to
      end

      def method_missing(*args)
        @delegate_to.each do |to|
          to.public_send(*args)
        end
      end
    end
  end
end
