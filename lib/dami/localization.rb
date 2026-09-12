# File: lib/dami/localization.rb
# frozen_string_literal: true
#raise "LOCALIZATION FILE RELOADED AT #{Time.now.to_f}"

module Dami
  class << self
    attr_reader :translations
  end
  
  @translations = {}
  @locale = nil
  
  # Process-wide default locale (set once at boot).
  def self.locale
    instance_variable_get(:@locale)
  end

  def self.locale=(new_locale)
    instance_variable_set(:@locale, new_locale&.to_sym)
  end

  # Per-thread override. Web servers run requests on threads, so a request's
  # locale must never leak into another request: set it here (or use
  # with_locale), never via Dami.locale= from inside a request.
  def self.thread_locale
    Thread.current[:dami_locale]
  end

  def self.thread_locale=(new_locale)
    Thread.current[:dami_locale] = new_locale&.to_sym
  end

  def self.current_locale
    locale = Thread.current[:dami_locale] || instance_variable_get(:@locale)

    # Only convert to symbol if locale exists and is not empty
    return locale.to_sym if locale && !locale.to_s.empty?

    if defined?(I18n) && I18n.respond_to?(:locale)
      i18n_locale = I18n.locale
      return i18n_locale.to_sym if i18n_locale
    end

    :en
  end
  def self.localize(scope, &block)
    scope_storage = (@translations[scope] ||= {})
    LocalizationProxy.new(scope_storage).instance_eval(&block)
  end
  
  def self.translate(key, *args)
    keys = key.to_s.split('.').map(&:to_sym)
    locale = current_locale
    
    message = @translations.dig(*keys.insert(1, locale))
    if message.is_a?(Proc)
      message.call(*args)
    else
      message || "translation missing: #{locale}.#{key}"
    end
  end
  
  # Thread-local: only the calling thread sees the temporary locale.
  def self.with_locale(temp_locale, &block)
    original_locale = Thread.current[:dami_locale]
    Thread.current[:dami_locale] = temp_locale&.to_sym
    yield
  ensure
    Thread.current[:dami_locale] = original_locale
  end
  # --- Helper Methods ---
  
  def self.localize_model(model_name, locale: nil)
    locale ||= current_locale
    @translations.dig(:models, locale, model_name, :model_name)
  end
  
  class << self
    alias_method :lm, :localize_model
  end
  
  def self.localize_field(model_name, field_name, locale: nil)
    locale ||= current_locale
    @translations.dig(:models, locale, model_name, field_name)
  end
  
  class << self
    alias_method :lf, :localize_field
  end
  
  # --- DSL Proxy Classes ---
  
  class LocalizationProxy
    def initialize(storage); @storage = storage; end
    def en(&block); locale(:en, &block); end
    def es(&block); locale(:es, &block); end
    def fr(&block); locale(:fr, &block); end
    def de(&block); locale(:de, &block); end
    def ja(&block); locale(:ja, &block); end
    def zh(&block); locale(:zh, &block); end
    def pt(&block); locale(:pt, &block); end
    def it(&block); locale(:it, &block); end
    def ru(&block); locale(:ru, &block); end
    def ar(&block); locale(:ar, &block); end
    
    def locale(lang_code, &block)
      locale_storage = (@storage[lang_code.to_sym] ||= {})
      LocaleProxy.new(locale_storage).instance_eval(&block)
    end
  end
  
  class LocaleProxy
    def initialize(storage); @storage = storage; end
    def set(key, value); @storage[key.to_sym] = value; end
    
    def attributes_for(model_name, &block)
      model_storage = (@storage[model_name.to_sym] ||= {})
      AttributesProxy.new(model_storage).instance_eval(&block)
    end
    
    def enum_for(model_name, attribute, &block)
      enum_storage = ((@storage[model_name.to_sym] ||= {})[attribute.to_sym] = {})
      AttributesProxy.new(enum_storage).instance_eval(&block)
    end
  end
  
  class AttributesProxy
    def initialize(storage); @storage = storage; end
    def set(key, value); @storage[key.to_sym] = value; end
  end
end