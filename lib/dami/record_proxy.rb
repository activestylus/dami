# frozen_string_literal: true
module Dami
  class RecordProxy
    include Dami::Plugins::Associations::RecordProxyMethods
def initialize(model_name, record, preloaded = {})
  @model_name = model_name
  @record = record
  @preloaded = preloaded
  define_relationship_accessors
end

def [](key)
  # If the key doesn't exist in @record, return nil
  @record[key]
end
    def to_h
      @record
    end
    private
    def wrap_preloaded(assoc_name, data, config)
      return nil if data.nil?
      model_name = config[:model] || assoc_name.to_s.pluralize.to_sym
      if data.is_a?(Array)
        data.map { |r| ::Dami::RecordProxy.new(model_name, r) }
      else
        ::Dami::RecordProxy.new(model_name, data)
      end
    end
  end
end