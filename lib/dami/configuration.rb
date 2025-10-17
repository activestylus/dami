# frozen_string_literal: true
module Dami
  def self.model(name, &block)
    config = ModelConfig.new(name)
    config.instance_eval(&block)
    (@models ||= {})[name] = config.to_h.freeze
  end
  class Configuration
    attr_accessor :models_path
    attr_accessor :migrations_path
    attr_accessor :schema_path
    def initialize
      @models_path = 'app/models'
      @migrations_path = 'db/migrations'
      @schema_path = 'db/schema.rb'
    end
  end
  def self.configuration
    @configuration ||= Configuration.new
  end
  def self.configure
    yield(configuration)
  end
  class ModelConfig
    def initialize(name)
      @config = { name: name, database: :default, fields: {}, virtual_fields: {}, protection: {}, relationships: {}, validations: {}, scopes: {}, nests: {} }
    end

    def nests(*names, **options)
      proxy = NestsProxy.new(@config[:nests])
      names.each do |name|
        proxy.nest(name, **options)
      end
    end

    def scopes(&block)
      ScopesProxy.new(@config[:scopes]).instance_eval(&block)
    end
    def database(name)
      @config[:database] = name
    end
    def fields(&block)
      FieldsProxy.new(@config[:fields]).instance_eval(&block)
    end
    def virtual(&block)
      FieldsProxy.new(@config[:virtual_fields]).instance_eval(&block)
    end
    def protection(&block)
      ProtectionProxy.new(@config[:protection]).instance_eval(&block)
    end
    def relationships(&block)
      RelationshipProxy.new(@config[:relationships]).instance_eval(&block)
    end
    def validate(&block)
      all_fields = @config[:fields].merge(@config[:virtual_fields])
      ValidationProxy.new(@config[:validations], all_fields).instance_eval(&block)
    end
    def to_h
      @config
    end
  end
  class FieldsProxy
    def initialize(target) @target = target end
    def field(name, type, **options)
      @target[name] = { type: type, **options }
    end
  end
  class ProtectionProxy
    def initialize(target) @target = target end
    def permit(*fields) @target[:permit] = fields end
    def protect(*fields) @target[:protect] = fields end
  end
  class RelationshipProxy
    def initialize(target) @target = target end
    def belongs_to(*names, **options)
      (@target[:belongs_to] ||= {}).merge!(parse_relations(names, options))
    end
    def has_one(*names, **options)
      (@target[:has_one] ||= {}).merge!(parse_relations(names, options))
    end
    def has_many(*names, **options)
      (@target[:has_many] ||= {}).merge!(parse_relations(names, options))
    end
    private
    def parse_relations(names, options)
      relations = {}
      options.each do |key, value|
        relations[key] = value if value.is_a?(Hash)
      end
      non_rel_opts = options.reject { |_, v| v.is_a?(Hash) }
      names.each do |name|
        relations[name] = non_rel_opts
      end
      relations
    end
  end
  class ValidationProxy
    def initialize(target, fields_config)
      @target = target
      @fields_config = fields_config
      @current_operations = [:create, :update]
      @current_field = nil
    end
    def on(*operations, &block)
      previous_operations = @current_operations
      @current_operations = operations.flatten
      instance_eval(&block)
      @current_operations = previous_operations
    end
    def all(except: [], only: [], **kwargs, &block)
      except = Array(except)
      only = Array(only)
      target_fields = if only.any?
        only
      elsif except.any?
        @fields_config.keys - except
      else
        @fields_config.keys
      end
      if kwargs.any? && !block
        target_fields.each do |field|
          @current_field = field
          kwargs.each do |rule_name, rule_value|
            if rule_value == true
              rule(rule_name)
            else
              rule([rule_name, rule_value])
            end
          end
          @current_field = nil
        end
      elsif block
        target_fields.each do |field|
          @current_field = field
          instance_eval(&block)
          @current_field = nil
        end
      end
    end

    def rule(*args, **kwargs)
      when_cond = kwargs.delete(:when)
      unless_cond = kwargs.delete(:unless)
      if_cond = kwargs.delete(:if)
      if @current_field
        field = @current_field
        rules = args
        rules += kwargs.map { |k, v| [k, v] } if kwargs.any?
      else
        field = args.first
        rules = args[1..-1]
        rules += kwargs.map { |k, v| [k, v] } if kwargs.any?
      end
      rules.each do |rule_def|
        rule_entry = {
          rule: rule_def,
          on: @current_operations.dup
        }
        rule_entry[:when] = when_cond if when_cond
        rule_entry[:unless] = unless_cond if unless_cond
        rule_entry[:if] = if_cond if if_cond
        (@target[field] ||= []) << rule_entry
      end
    end
  end
  class ScopesProxy
    def initialize(target)
      @target = target
    end
    def scope(name, body)
      @target[name] = body
    end
  end
  class Dami::NestsProxy
    def initialize(target)
      @target = target
    end

    def nest(association_name, **options)
      attributes_key = "#{association_name}_attributes".to_sym
      @target[attributes_key] = {
        association_name: association_name,
        allow_destroy: options.fetch(:allow_destroy, false) # Defaults to false for security
      }.freeze
    end
  end
end