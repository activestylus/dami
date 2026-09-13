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
    # A step that talks to the outside world. retry_options: { on: [SomeError], times: 2 }
    # retries that many times on those exceptions; timeout: is in seconds.
    def perform(name, retry_options: {}, timeout: nil, &block)
      action = -> do
        retry_exceptions = Array(retry_options[:on])
        max_attempts = (retry_options[:times] || 0) + 1   # the first attempt plus the retries
        attempts = 0
        begin
          attempts += 1
          block.call
        rescue *retry_exceptions => e
          raise if attempts >= max_attempts
          retry
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