module Dami
  def self.model(name, &block)
    config = ModelConfig.new(name)
    config.instance_eval(&block)
    (@models ||= {})[name] = config.to_h.merge(name: name).freeze
  end
  def self.behavior(model_name, &block)
    model_config = find_model(model_name)
    BehaviorProxy.new(model_config).instance_eval(&block)
  end
  def self.scopes(model_name, &block)
    model_config = find_model(model_name)
    ScopesProxy.new(model_config.fetch(:scopes, {})).instance_eval(&block)
  end
  class Configuration
    attr_accessor :models_path, :migrations_path, :schema_path, :database_config
    def initialize
      @models_path = 'app/models'
      @migrations_path = 'db/migrations'
      @schema_path = 'db/schema.rb'
      @database_config = {}
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
      @config = {
        database: :default,
        fields: {},
        virtual_fields: {},
        protection: {},
        relationships: {},
        validations: {},
        scopes: {},
        nests: {}
      }
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
    def relationships(&block)
      RelationshipProxy.new(@config[:relationships]).instance_eval(&block)
    end
    def nests(*names, **options)
      proxy = NestsProxy.new(@config[:nests])
      names.each { |name| proxy.nest(name, **options) }
    end
    def validate(*args, &block)
      raise Dami::InvalidDSLError.new('validate', 'behavior')
    end
    def protection(*args, &block)
      raise Dami::InvalidDSLError.new('protection', 'behavior')
    end
    def scope(*args, &block)
      raise Dami::InvalidDSLError.new('scope', 'scopes')
    end
    def to_h
      @config
    end
  end
  class FieldsProxy
    def initialize(target)
      @target = target
    end
    def field(name, type, **options)
      @target[name] = { type: type, **options }
    end
  end
  class RelationshipProxy
    def initialize(target)
      @target = target
    end
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
      options.each { |key, value| relations[key] = value if value.is_a?(Hash) }
      non_rel_opts = options.reject { |_, v| v.is_a?(Hash) }
      names.each { |name| relations[name] = non_rel_opts }
      relations
    end
  end
  class BehaviorProxy
    def initialize(model_config)
      @model_config = model_config
      @model_config[:validations] ||= {}
      @model_config[:protection] ||= {}
      @model_config[:protection][:protect] ||= []
      @model_config[:protection][:permit] ||= []
    end
    def validate(&block)
      validator = ValidationBuilder.new(@model_config[:validations], model_config: @model_config)
      validator.instance_eval(&block)
    end
    def protection(&block)
      protector = ProtectionBuilder.new(@model_config[:protection])
      protector.instance_eval(&block)
    end
    def on(operation, &block)
      validator = ValidationBuilder.new(@model_config[:validations], context: operation, model_config: @model_config)
      validator.instance_eval(&block)
    end
    def fields(*args, &block)
      raise Dami::InvalidDSLError.new('fields', 'model')
    end
    def virtual(*args, &block)
      raise Dami::InvalidDSLError.new('virtual', 'model')
    end
    def relationships(*args, &block)
      raise Dami::InvalidDSLError.new('relationships', 'model')
    end
    def nests(*args, &block)
      raise Dami::InvalidDSLError.new('nests', 'model')
    end
    def scope(*args, &block)
      raise Dami::InvalidDSLError.new('scope', 'scopes')
    end
    class ValidationBuilder
      def initialize(config, context: nil, model_config: nil)
        @config = config
        @context = context
        @model_config = model_config
      end
      def rule(field, *rules, **options, &block)
        field = field.to_sym
        @config[field] ||= []
        if_cond = options.delete(:if)
        unless_cond = options.delete(:unless)
        when_cond = options.delete(:when)
        rules.concat(options.map { |k, v| v == true ? k : [k, v] })
        rules.each do |rule_def|
          rule_entry = { rule: rule_def, on: @context ? [@context] : [:create, :update] }
          rule_entry[:if] = if_cond if if_cond
          rule_entry[:unless] = unless_cond if unless_cond
          rule_entry[:when] = when_cond if when_cond
          @config[field] << rule_entry
        end
      end
      def all(only: nil, except: nil, **kwargs, &block)
        all_fields = []
        if @model_config
          all_fields.concat(@model_config[:fields].keys) if @model_config[:fields]
          all_fields.concat(@model_config[:virtual_fields].keys) if @model_config[:virtual_fields]
        end
        fields_to_validate = if only
          Array(only).map(&:to_sym) & all_fields
        elsif except
          all_fields - Array(except).map(&:to_sym)
        else
          all_fields
        end
        if kwargs.any?
          fields_to_validate.each do |field|
            rule(field, **kwargs)
          end
        end
        if block_given?
          temp_builder = TempRuleBuilder.new(@context)
          temp_builder.instance_eval(&block)
          fields_to_validate.each do |field|
            temp_builder.rules.each do |rule_def|
              rule(field, *rule_def[:args], **rule_def[:kwargs])
            end
          end
        end
      end
      def on(operation, &block)
        nested = ValidationBuilder.new(@config, context: operation, model_config: @model_config)
        nested.instance_eval(&block)
      end
      class TempRuleBuilder
        attr_reader :rules
        def initialize(context)
          @context = context
          @rules = []
        end
        def rule(*args, **kwargs)
          @rules << { args: args, kwargs: kwargs }
        end
      end
    end
    class ProtectionBuilder
      def initialize(config)
        @config = config
        @config[:protect] ||= []
        @config[:permit] ||= []
      end
      def protect(*fields)
        @config[:protect].concat(fields.map(&:to_sym))
        @config[:protect].uniq!
      end
      def permit(*fields)
        @config[:permit].concat(fields.map(&:to_sym))
        @config[:permit].uniq!
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
    def fields(*args, &block)
      raise Dami::InvalidDSLError.new('fields', 'model')
    end
    def validate(*args, &block)
      raise Dami::InvalidDSLError.new('validate', 'behavior')
    end
    def protection(*args, &block)
      raise Dami::InvalidDSLError.new('protection', 'behavior')
    end
  end
  class NestsProxy
    def initialize(target)
      @target = target
    end
    def nest(association_name, **options)
      attributes_key = "#{association_name}_attributes".to_sym
      @target[attributes_key] = {
        association_name: association_name,
        allow_destroy: options.fetch(:allow_destroy, false)
      }.freeze
    end
  end
end