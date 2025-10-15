# frozen_string_literal: true
module Dami
  @databases = {}
  @models = {}
  @flows = {}
  def self.plugin(mod)
    mod.apply(self) if mod.respond_to?(:apply)
  end
  def self.connect(name = :default, adapter:, **config)
    adapter_class = Dami::Adapters.const_get(adapter.to_s.capitalize)
    db_instance = adapter_class.new(config)
    db_instance.connect
    @databases[name] = db_instance
    db_instance
  end
  def self.database(name = :default)
    @databases.fetch(name) { raise "Database :#{name} not connected" }
  end
  def self.find_model(name)
    @models.fetch(name) { raise "Model :#{name} not defined" }
  end
  def self.db(model_name)
    model_config = find_model(model_name)
    db_name = model_config[:database] || :default
    
    # Create a custom builder class with scope methods
    builder_class = create_builder_with_scopes(model_name, model_config[:scopes] || {})
    builder_class.new(model_name, db_name: db_name)
  end
    def self.run(flow_name, **params)
      flow = find_flow(flow_name)
      Success.new(flow.call(**params))
    end
    private
  def self.create_builder_with_scopes(model_name, scopes)
    return Dami::Query::Builder if scopes.empty?
    
    # Create a subclass with scope methods defined
    Class.new(Dami::Query::Builder) do
      scopes.each do |name, body|
        define_method(name) do |*args|
          instance_exec(*args, &body)
        end
      end
    end
  end
end