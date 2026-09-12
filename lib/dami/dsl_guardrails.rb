# File: lib/dami/dsl_guardrails.rb

module Dami
  module DSLGuardrails
    # Methods that belong in Dami.behavior
    def validate(*args, &block)
      raise InvalidDSLError.new('validate', 'behavior')
    end
    
    def protection(*args, &block)
      raise InvalidDSLError.new('protection', 'behavior')
    end
    
    def on(*args, &block)
      raise InvalidDSLError.new('on', 'behavior')
    end
    
    # Methods that belong in Dami.model
    def fields(*args, &block)
      raise InvalidDSLError.new('fields', 'model')
    end
    
    def virtual(*args, &block)
      raise InvalidDSLError.new('virtual', 'model')
    end
    
    def relationships(*args, &block)
      raise InvalidDSLError.new('relationships', 'model')
    end
    
    def nests(*args, &block)
      raise InvalidDSLError.new('nests', 'model')
    end
    
    # Methods that belong in Dami.scopes
    def scope(*args, &block)
      raise InvalidDSLError.new('scope', 'scopes')
    end
    
    # Methods that belong in Dami.present
    def helper(*args, &block)
      raise InvalidDSLError.new('helper', 'present')
    end
  end
end