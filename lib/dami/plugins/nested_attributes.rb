# frozen_string_literal: true
module Dami
  module Plugins
    module NestedAttributes
      def self.apply(dami_module)
        dami_module.extend(ClassMethods)
      end
    end
  end
end