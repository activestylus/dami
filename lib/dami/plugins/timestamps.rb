# frozen_string_literal: true
module Dami
  module Plugins
    module Timestamps
      def self.apply(dami_module)
        dami_module.extend(Dami::Plugins::Timestamps::ClassMethods)
      end
    end
  end
end