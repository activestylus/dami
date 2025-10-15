# frozen_string_literal: true
module Dami
  class ValidationError < StandardError
    attr_reader :errors
    def initialize(message, errors = {})
      super(message)
      @errors = errors
    end
  end
  class ProtectionError < StandardError
    attr_reader :fields
    def initialize(message, fields = [])
      super(message)
      @fields = fields
    end
  end
  class UnknownFieldsError < StandardError
    attr_reader :fields
    def initialize(message, fields = [])
      super(message)
      @fields = fields
    end
  end
  class NoMatchingRow < StandardError; end
  class InvalidCommand < StandardError; end
end