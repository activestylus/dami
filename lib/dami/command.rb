# frozen_string_literal: true
module Dami
  class Command
    def self.requires(*keys)
      @required_context = keys
      keys.each { |key| define_method(key) { @context.fetch(key) } }
    end
    def self.compose(command_class, mapping = {})
      (@composed_commands ||= []) << { command: command_class, mapping: mapping }
    end
    def self.validate(name, error: { message: 'is invalid', code: :invalid }, **conds, &block)
      (@validations ||= []) << { name: name, error: error, if: conds[:if], unless: conds[:unless], block: block }
    end
    def self.transform(name, &block)
      (@transformations ||= []) << { name: name, block: block }
    end
    attr_reader :original, :data, :context, :errors
    def initialize(original:, data:, **context)
      @original = (original || {}).transform_keys(&:to_sym)
      @data = data.transform_keys(&:to_sym)
      @context = context
      @errors = {}
      validate_required_context!
    end
    def call
      run_composed_commands
      run_validations
      run_transformations if valid?
      self
    end
    def valid?
      @errors.empty?
    end
    def get(key)
      @data[key]
    end
    private
    def validate_required_context!
      missing = (self.class.instance_variable_get(:@required_context) || []) - @context.keys
      raise ArgumentError, "Missing required context: #{missing.join(', ')}" unless missing.empty?
    end
    def run_composed_commands
      (self.class.instance_variable_get(:@composed_commands) || []).each do |c|
        mapped_ctx = c[:mapping].transform_values { |v| @context[v] }
        cmd = c[:command].new(original: @original, data: @data, **@context.merge(mapped_ctx)).call
        @errors.merge!(cmd.errors) { |_, old, new| old + new } unless cmd.valid?
      end
    end
    def run_validations
      (self.class.instance_variable_get(:@validations) || []).each do |v|
        next if v[:if] && !instance_eval(&v[:if])
        next if v[:unless] && instance_eval(&v[:unless])
        unless instance_eval(&v[:block])
          (@errors[v[:name]] ||= []) << v[:error]
        end
      end
    end
    def run_transformations
      (self.class.instance_variable_get(:@transformations) || []).each do |t|
        @data = instance_exec(@data.dup, &t[:block])
      end
    end
  end
end