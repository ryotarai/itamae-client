require 'logger'

module Itamae
  module Client
    module Logger
      class File < ::Logger
        def initialize(options)
          path = options.fetch('path')
          super(open(path, 'a'))
        end
      end
    end
  end
end
