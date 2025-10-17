

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

    # Fix: Ensure the method accepts the context parameter
    def call(context)
      context.instance_exec(&@block)
    rescue => e
      handle_exception(e, context)
    end

    def run_after_commit_hooks
      @after_commit_hooks.each(&:call)
    end

    def rescue_from(exception_class, &handler)
      @rescue_handlers[exception_class] = handler
    end

    private

    def handle_exception(exception, context)
      handler = @rescue_handlers.find { |klass, _| exception.is_a?(klass) }&.last
      handler ? handler.call(exception, context) : raise(exception)
    end
  end
end