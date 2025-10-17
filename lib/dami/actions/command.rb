# frozen_string_literal: true
module Dami
  class Command
    def self.requires_context(*keys)
      @required_context = keys
      keys.each { |key| define_method(key) { @context.fetch(key) } }
    end
    def self.validate(name, error:, **conds, &block)
      (@validations ||= []) << { name: name, error: error, if: conds[:if], unless: conds[:unless], block: block }
    end
    def self.transform(name, &block)
      (@transformations ||= []) << { name: name, block: block }
    end
    def self.apply(callable)
      callable.call(self)
    end
    def self.compose(command_class, mapping = {})
      (@composed_commands ||= []) << { command: command_class, mapping: mapping }
    end
    def self.clear_definitions!
      @required_context, @validations, @transformations, @composed_commands = nil, nil, nil, nil
    end
    attr_reader :original, :data, :context, :errors
    def initialize(opts)
      @original = (opts[:original] || {}).transform_keys(&:to_sym)
      @data = opts[:data].transform_keys(&:to_sym)
      @context = opts[:context] || {}
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
    def changed?(field)
      sym_field = field.to_sym
      @data.key?(sym_field) && @original[sym_field] != @data[sym_field]
    end
    private
    def validate_required_context!
      missing = (self.class.instance_variable_get(:@required_context) || []) - @context.keys
      raise ArgumentError, "Missing required context: #{missing.join(', ')}" unless missing.empty?
    end
    def run_composed_commands
      (self.class.instance_variable_get(:@composed_commands) || []).each do |c|
        mapped_ctx = c[:mapping].transform_values { |v| @context[v] }
        cmd = c[:command].new(original: @original, data: @data, context: @context.merge(mapped_ctx)).call
        @errors.merge!(cmd.errors) { |_, old, new| old + new } unless cmd.valid?
        @data = cmd.data # Carry over transformed data from composed command
      end
    end
    def run_validations
      (self.class.instance_variable_get(:@validations) || []).each do |v|
        next if v[:if] && !instance_exec(&v[:if])
        next if v[:unless] && instance_exec(&v[:unless])
        unless instance_exec(&v[:block])
          (@errors[v[:name]] ||= []) << v[:error]
        end
      end
    end
    def run_transformations
      current_data = @data.dup
      (self.class.instance_variable_get(:@transformations) || []).each do |t|
        result = instance_exec(current_data, &t[:block])
        current_data.merge!(result) if result.is_a?(Hash)
      end
      @data = current_data
    end
  end
end