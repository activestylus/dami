# frozen_string_literal: true
module Dami
  module Plugins
    module Validations
      class Registry
        def initialize
          @rules = {}
        end
        def register(name, rule_def)
          @rules[name.to_sym] = rule_def
        end
        def get(name)
          @rules[name.to_sym] || raise("Unknown validation rule: #{name}")
        end
        def validate(value, rule_name, params = [], context = {})
          rule = get(rule_name)
          rule_config = rule.is_a?(Proc) ? rule.call(*params) : rule
          check = rule_config[:check]
          message = rule_config[:message]
          return message unless check
          result = check.arity == 1 ? check.call(value) : check.call(value, context)
          result ? nil : message
        end
      end
      module DamiClassMethods
        def validation_registry
          @validation_registry ||= Registry.new
        end
        def rules(namespace = :default, rules_hash)
          rules_hash.each do |name, rule_def|
            validation_registry.register(name, rule_def)
          end
        end
        def validate!(model_name, attrs, on: :create)
          model_config = find_model(model_name)
          errors = {}
          (model_config.dig(:validations) || {}).each do |field, rule_definitions|
            next unless on == :create || attrs.key?(field)
            Array(rule_definitions).each do |rule_def|
              rule_options = rule_def.is_a?(Hash) ? rule_def : { rule: rule_def }
              next if should_skip_validation?(rule_options, attrs, on)
              error_msg = validate_rule(attrs[field], rule_options[:rule], attrs)
              (errors[field] ||= []) << error_msg if error_msg
            end
          end
          raise ValidationError.new("Validation failed", errors) unless errors.empty?
        end
        private
        def should_skip_validation?(rule_def, attrs, on)
          return true if rule_def[:on] && !Array(rule_def[:on]).include?(on)
          if (if_cond = rule_def[:if])
            return true unless if_cond.is_a?(Proc) && if_cond.call(attrs)
          end
          if (unless_cond = rule_def[:unless])
            if unless_cond.is_a?(Proc)
              return true if unless_cond.call(attrs)
            else
              return true if unless_cond.all? { |k, v| attrs[k] == v }
            end
          end
          if (when_cond = rule_def[:when])
            return true unless when_cond.all? { |k, v| attrs[k] == v }
          end
          false
        end
        def validate_rule(value, rule, context)
          case rule
          when Symbol
            validation_registry.validate(value, rule, [], context)
          when Array
            validation_registry.validate(value, rule.first, rule[1..-1], context)
          end
        end
      end
      def self.apply(dami_module)
        dami_module.extend(DamiClassMethods)
      end
    end
  end
end