# File: lib/dami/validation_rules.rb

module Dami
  # Numeric coercion used by the min/max rules: accepts Integer, Float, numeric
  # strings ("12.50"); returns nil for anything else so decimals are compared
  # as decimals instead of being truncated by to_i.
  def self.numeric(value)
    return value if value.is_a?(Numeric)
    Float(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  # This method now handles both registering the rule logic AND their default messages.
def self.register_default_rules!(registry: :default)
  # Register the validation rule checks
  rules(registry, {
    required: { check: ->(v) { !v.nil? && !v.to_s.strip.empty? } },
    presence: { check: ->(v) { !v.nil? && !v.to_s.strip.empty? } },
    email: { check: ->(v) { v.to_s =~ /\A[^@\s]+@[^@\s]+\z/ } },
    inclusion: ->(vals) { { check: ->(v) { vals.include?(v) } } },
    format: ->(pattern) { { check: ->(v) { v.nil? || v.to_s.match?(pattern) } } },
    min_length: ->(min) { { check: ->(v) { v.to_s.length >= min } } },
    max_length: ->(max) { { check: ->(v) { v.to_s.length <= max } } },
    min: ->(min) { { check: ->(v) { (n = Dami.numeric(v)) && n >= min } } },
    max: ->(max) { { check: ->(v) { (n = Dami.numeric(v)) && n <= max } } }
  })
  
  # Register default messages in the translation system
  Dami.localize :validations do
    en do
      set :required, "is required"
      set :presence, "is required"
      set :email, "must be valid email"
      set :inclusion, "is not in the list of accepted values"
      set :format, "has invalid format"
      set :min_length, ->(min) { "must be at least #{min} characters" }
      set :max_length, ->(max) { "must be at most #{max} characters" }
      set :min, ->(min) { "must be at least #{min}" }
      set :max, ->(max) { "must be at most #{max}" }
    end
  end
  
  # Keep @rule_messages for backwards compatibility
  @rule_messages ||= {}
  @rule_messages[registry] = {
    required: "is required",
    presence: "is required",
    email: "must be valid email",
    inclusion: "is not in the list of accepted values",
    format: "has invalid format",
    min_length: ->(min) { "must be at least #{min} characters" },
    max_length: ->(max) { "must be at most #{max} characters" },
    min: ->(min) { "must be at least #{min}" },
    max: ->(max) { "must be at most #{max}" }
  }
end

def self.override_messages(registry, messages)
  # Override in both systems
  @rule_messages ||= {}
  @rule_messages[registry] ||= {}
  @rule_messages[registry].merge!(messages)
  
  # Also override in translation system
  Dami.localize :validations do
    en do
      messages.each { |key, value| set key, value }
    end
  end
end
end