# frozen_string_literal: true
require 'timeout'

module Dami
  class FlowContext
    attr_reader :params
    def initialize(params)
      @params = params
      @after_commit_hooks = []
      define_param_accessors
    end
    def prepare(command_class, with:, original: nil)
      command = command_class.new(original: original, data: with, context: @params)
      command.call
      halt(Dami::Failure.new(command.errors)) unless command.valid?
      command.data
    end
    # THE FIX IS HERE: Renamed 'retry:' to 'retry_options:'
    def perform(name, retry_options: {}, timeout: nil, &block)
      action = -> do
        # THE FIX: Use the new parameter name 'retry_options'
        retry_exceptions = Array(retry_options[:on])
        # Add 1 for the initial attempt.
        max_attempts = (retry_options[:times] || 0) + 1
        attempts = 0
        begin
          attempts += 1
          block.call
        rescue *retry_exceptions => e
          raise if attempts >= max_attempts
          retry # This 'retry' keyword is correct because it's inside the rescue block
        end
      end
      if timeout
        Timeout.timeout(timeout) { action.call }
      else
        action.call
      end
    end
    def succeed(with:, and_then: [])
      @after_commit_hooks.concat(Array(and_then))
      halt(Dami::Success.new(with))
    end
    def run(flow_name, **params)
      Dami.run(flow_name, **(@params.merge(params)))
    end
    def db(model_name)
      Dami.db(model_name)
    end
    def halt(value)
      throw :halt, value
    end
    def run_after_commit_hooks!
      @after_commit_hooks.each(&:call)
    end
    private
    def define_param_accessors
      @params.each_key do |key|
        define_singleton_method(key) { @params[key] }
      end
    end
  end
end