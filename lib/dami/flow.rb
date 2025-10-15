# frozen_string_literal: true
module Dami
  def self.flow(name, &block)
    (@flows ||= {})[name] = Flow.new(block)
  end
  def self.find_flow(name)
    (@flows || {}).fetch(name) { raise "Flow :#{name} not defined" }
  end
  class Flow
    def initialize(block)
      @block = block
      @rescue_handlers = {}
      @after_commit_hooks = []
    end
    def call(**params)
      context = FlowContext.new(@after_commit_hooks)
      catch(:halt) do
        context.instance_exec(**params, &@block)
      end
    rescue => e
      handle_exception(e, params)
    end
    def run_after_commit_hooks
      @after_commit_hooks.each(&:call)
    end
    def rescue_from(exception_class, &handler)
      @rescue_handlers[exception_class] = handler
    end
    private
    def handle_exception(exception, context_params)
      handler = @rescue_handlers.find { |klass, _| exception.is_a?(klass) }&.last
      handler ? handler.call(exception, context_params) : raise(exception)
    end
  end
  class FlowContext
    def initialize(after_commit_hooks)
      @after_commit_hooks = after_commit_hooks
    end
    def call(step_name, retry: {}, timeout: nil, &block)
      block.call
    end
    def after_commit(&block)
      @after_commit_hooks << block
    end
    def halt(value)
      throw :halt, value
    end
def db(model_name)
  model_config = find_model(model_name)
  db_name = model_config[:database] || :default
  scopes = model_config[:scopes] || {}
  
  builder_class = Builder.with_scopes(model_name, scopes)
  builder_class.new(model_name, db_name: db_name)
end
    def run(flow_name, **params)
      Dami.run(flow_name, **params)
    end
  end
end