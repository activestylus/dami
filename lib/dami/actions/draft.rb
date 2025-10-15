# frozen_string_literal: true
module Dami
  class Draft
    attr_reader :original, :data, :errors, :context
    def initialize(original:, data:, context: {})
      @original = (original || {}).freeze
      @data = data
      @context = context
      @errors = {}
    end
    def verify(name, error:, &block)
      return unless instance_exec(&block) == false
      (@errors[name] ||= []) << error
    end
    def transform(name, &block)
      @data = instance_exec(@data.dup, &block)
    end
    def apply(callable)
      callable.call(self)
    end
    def prevent_changes(*fields, message: "cannot be changed")
      fields.each do |field|
        verify(field, error: message) { !changed?(field) }
      end
    end
    def changed?(field)
      @data.key?(field) && @original[field] != @data[field]
    end
    def get(key)
      @data[key]
    end
    def valid?
      @errors.empty?
    end
  end
end