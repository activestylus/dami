# File: lib/dami/errors.rb

module Dami
  # Base error class
  class Error < StandardError; end
  
  # Validation errors
  class ValidationError < Error
    attr_reader :errors
    
    def initialize(message = "Validation failed", errors = {})
      @errors = errors
      super(message)
    end
  end
  
  # Protection errors - backward compatible
  class ProtectionError < Error
    attr_reader :fields
    
    def initialize(message, fields = nil)
      @fields = fields
      super(message)
    end
  end
  
  class UnknownFieldsError < Error
    attr_reader :fields
    
    def initialize(message, fields = nil)
      @fields = fields
      super(message)
    end
  end
  
  # Database errors
  class ForeignKeyViolation < Error
    attr_reader :table, :column, :value
    
    def initialize(message, table: nil, column: nil, value: nil)
      @table = table
      @column = column
      @value = value
      super("Foreign key violation: #{message}")
    end
  end
  
  class UniqueConstraintViolation < Error
    attr_reader :table, :column, :value

    def initialize(message, table: nil, column: nil, value: nil)
      @table = table
      @column = column
      @value = value
      super("Unique constraint violation: #{message}")
    end
  end

  class NotNullViolation < Error
    attr_reader :table, :column

    def initialize(message, table: nil, column: nil)
      @table = table
      @column = column
      super("Not-null constraint violation: #{message}")
    end
  end
  
  # DSL Architecture errors
  class InvalidDSLError < Error
    def initialize(method_name, correct_location)
      super(
        "'#{method_name}' is not allowed here. " \
        "Please define it in a Dami.#{correct_location} block."
      )
    end
  end
  
  # Command errors
  class InvalidCommand < Error; end

  # Raised internally by Dami.run to abort the surrounding transaction when a
  # flow halts with a Failure. Never escapes Dami.run.
  class Rollback < Error; end

  # Raised when a caller passes something that is not a plain SQL identifier
  # (letters, digits, underscore, dot) where a column or table name is expected.
  class InvalidIdentifier < Error; end
end