# frozen_string_literal: true
module Dami
  module Plugins
    module Protection
      module DamiClassMethods
        def filter_input!(model_name, attrs, permit: [], protect: true)
          model_config = find_model(model_name)
          virtual_fields = (model_config[:virtual_fields] || {}).keys
          known_fields = (model_config[:fields] || {}).keys + virtual_fields + [:id]
          unknown = attrs.keys - known_fields
          raise UnknownFieldsError.new("Unknown fields: #{unknown.join(', ')}", unknown) unless unknown.empty?
          if protect
            protections = model_config.dig(:protection, :protect) || []
            permitted_by_model = model_config.dig(:protection, :permit) || []
            permitted = permit + permitted_by_model
            violations = attrs.keys.select do |key|
              protections.include?(key) && !permitted.include?(key)
            end
            raise ProtectionError.new("Protected fields not permitted: #{violations.join(', ')}", violations) unless violations.empty?
          end
          attrs.reject { |k, _| virtual_fields.include?(k) }
        end
      end
      def self.apply(dami_module)
        dami_module.extend(DamiClassMethods)
      end
    end
  end
end