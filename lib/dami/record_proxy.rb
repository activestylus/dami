# frozen_string_literal: true
module Dami
  class RecordProxy
    # The explicit include is removed. The plugin system is the single
    # source of truth for injecting behavior.

    def initialize(model_name, record, preloaded = {})
      @model_name = model_name
      @record = record
      @preloaded = preloaded
      # The direct call to define_relationship_accessors is also removed.
      # The plugin's `apply` method will handle this by prepending a
      # new `initialize` method that calls `super` and then does its work.
    end

    def [](key)
      @record[key]
    end

    def to_h
      @record
    end
  end
end