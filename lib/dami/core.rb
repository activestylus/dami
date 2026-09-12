# File: lib/dami/core.rb

require_relative 'adapters/sqlite/connection'

module Dami
  @databases = {}
  @models = {}
  @flows = {}
  @presenter_modules = {}

  def self.plugin(mod)
    mod.apply(self) if mod.respond_to?(:apply)
  end

def self.clear_all!
    @databases.clear
    @models.clear
    @flows.clear
    @presenter_modules&.clear
    (@translations || {}).clear
    Plugins::Associations.clear_cache!
  end


def self.present(model_name, &block)
  presenter_module = Module.new
  presenter_module.module_eval(&block)  # Changed from instance_eval
  (@presenter_modules ||= {})[model_name] = presenter_module
end

  def self.find_presenter_module(model_name)
    (@presenter_modules || {})[model_name]
  end

  # RecordProxy#initialize (extended by the Associations plugin) already applies
  # the presenter, the association accessors and the field accessors.
  def self.wrap_record(model_name, record_hash)
    return nil unless record_hash
    ::Dami::RecordProxy.new(model_name, record_hash)
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
    builder_class = create_builder_with_scopes(model_name, model_config[:scopes] || {})
    builder_class.new(model_name, db_name: db_name)
  end

  # Runs a flow inside one transaction.
  #   * A Success halt commits.
  #   * A Failure halt ROLLS BACK every write the flow made (raising Rollback
  #     out of the transaction block is what triggers it).
  #   * An unhandled exception rolls back and re-raises.
  # after-commit hooks run only once the transaction has actually committed.
  def self.run(flow_name, **params)
    flow = find_flow(flow_name)
    context = FlowContext.new(params)
    result = nil
    begin
      Dami.database.transaction do
        result = catch(:halt) { flow.call(context) }
        raise Rollback if result.is_a?(Failure)
      end
    rescue Rollback
      # Intentional: the transaction was rolled back; `result` is the Failure.
    end
    context.run_after_commit_hooks! if result.is_a?(Success)
    result
  end

  def self.create_builder_with_scopes(model_name, scopes)
    return Dami::Query::Builder if scopes.empty?
    Class.new(Dami::Query::Builder) do
      scopes.each do |name, body|
        define_method(name) do |*args|
          instance_exec(*args, &body)
        end
      end
    end
  end
  private_class_method :create_builder_with_scopes
end