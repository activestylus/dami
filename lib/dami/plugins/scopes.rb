# lib/dami/plugins/scopes.rb
# frozen_string_literal: true
module Dami
  module Plugins
    module Scopes
      module ClassMethods
        def scopes(&block)
          @scopes_definitions ||= {}
          instance_eval(&block) if block_given?
          @scopes_definitions
        end
        
        def scope(name, body)
          (@scopes_definitions ||= {})[name] = body
        end
      end
      def self.apply(dami_module)
        dami_module.extend(Dami::Plugins::Scopes::ClassMethods)
      end
    end
  end
end