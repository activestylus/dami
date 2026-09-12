# File: lib/dami/record_proxy.rb

# frozen_string_literal: true
module Dami
  class RecordProxy
    def initialize(model_name, record, preloaded = {})
      @model_name = model_name
      @record = record
      @preloaded = preloaded
    end

    def [](key)
      @record[key]
    end

    def to_h
      @record
    end

    # This helper is called by the associations plugin's initialize wrapper.
    def _define_fallback_accessors!
      return unless @record.is_a?(Hash)
      @record.each_key do |key|
        unless respond_to?(key)
          define_singleton_method(key) do
            @record[key]
          end
        end
      end
    end
  end
end