# File: test/localization_helpers_test.rb
require_relative 'test_helper'

class LocalizationHelpersTest < Minitest::Test
def setup
  super
  # Reset the *actual* instance variables used by the implementation
  Dami.instance_variable_set(:@translations, {})
  Dami.instance_variable_set(:@locale, nil)
end

def teardown
    # 1. Resets Dami's manual override
    Dami.instance_variable_set(:@locale, nil)
    
    # 2. Resets the I18n pollution (This fixes Failure 2)
    if defined?(I18n) && I18n.respond_to?(:locale=)
      I18n.locale = :en
    end
    
    super
  end
  def test_localize_model_returns_translated_name
    Dami.localize :models do
      en { attributes_for(:users) { set :model_name, "User" } }
      es { attributes_for(:users) { set :model_name, "Usuario" } }
    end
    
    Dami.locale = :en
    assert_equal "User", Dami.localize_model(:users)
    
    Dami.locale = :es
    assert_equal "Usuario", Dami.localize_model(:users)
  end
  
  def test_lm_is_alias_for_localize_model
    Dami.localize :models do
      en { attributes_for(:users) { set :model_name, "User" } }
    end
    
    Dami.locale = :en
    assert_equal "User", Dami.lm(:users)
  end
  
  def test_localize_field_returns_translated_label
    Dami.localize :models do
      en do
        attributes_for :users do
          set :first_name, "First Name"
          set :email, "Email Address"
        end
      end
      es do
        attributes_for :users do
          set :first_name, "Nombre"
          set :email, "Correo Electrónico"
        end
      end
    end
    
    Dami.locale = :en
    assert_equal "First Name", Dami.localize_field(:users, :first_name)
    assert_equal "Email Address", Dami.localize_field(:users, :email)
    
    Dami.locale = :es
    assert_equal "Nombre", Dami.localize_field(:users, :first_name)
    assert_equal "Correo Electrónico", Dami.localize_field(:users, :email)
  end
  
  def test_lf_is_alias_for_localize_field
    Dami.localize :models do
      en { attributes_for(:users) { set :first_name, "First Name" } }
    end
    
    Dami.locale = :en
    assert_equal "First Name", Dami.lf(:users, :first_name)
  end
  
  def test_explicit_locale_parameter_overrides_current
    Dami.localize :models do
      en { attributes_for(:users) { set :first_name, "First Name" } }
      es { attributes_for(:users) { set :first_name, "Nombre" } }
      fr { attributes_for(:users) { set :first_name, "Prénom" } }
    end
    
    Dami.locale = :en
    assert_equal "Prénom", Dami.lf(:users, :first_name, locale: :fr)
    assert_equal "First Name", Dami.lf(:users, :first_name)  # Still English
  end
  
  def test_current_locale_uses_manual_override_first
    Dami.locale = :es
    assert_equal :es, Dami.current_locale
  end
  
  def test_current_locale_falls_back_to_en
    # Ensure no locale is set
    Dami.instance_variable_set(:@locale, nil)
    assert_equal :en, Dami.current_locale
  end
  
  
  def test_with_locale_temporarily_switches_locale
    Dami.localize :models do
      en { attributes_for(:users) { set :first_name, "First Name" } }
      fr { attributes_for(:users) { set :first_name, "Prénom" } }
    end
    
    Dami.locale = :en
    assert_equal "First Name", Dami.lf(:users, :first_name)
    
    Dami.with_locale(:fr) do
      assert_equal "Prénom", Dami.lf(:users, :first_name)
    end
    
    assert_equal "First Name", Dami.lf(:users, :first_name)
  end
  
  def test_with_locale_restores_even_on_error
    Dami.locale = :en
    
    begin
      Dami.with_locale(:es) do
        raise "Test error"
      end
    rescue => e
      # Error expected
    end
    
    assert_equal :en, Dami.current_locale
  end
  
  def test_returns_nil_for_missing_translation
    Dami.localize :models do
      en { attributes_for(:users) { set :first_name, "First Name" } }
    end
    
    Dami.locale = :en
    assert_nil Dami.lf(:users, :nonexistent_field)
  end
  
  def test_returns_nil_for_missing_locale
    Dami.localize :models do
      en { attributes_for(:users) { set :first_name, "First Name" } }
    end
    
    Dami.locale = :de  # German not defined
    assert_nil Dami.lf(:users, :first_name)
  end
  
  def test_returns_nil_for_missing_model
    Dami.localize :models do
      en { attributes_for(:users) { set :first_name, "First Name" } }
    end
    
    Dami.locale = :en
    assert_nil Dami.lf(:nonexistent_model, :first_name)
  end
  
  def test_localize_model_with_explicit_locale
    Dami.localize :models do
      en { attributes_for(:products) { set :model_name, "Product" } }
      es { attributes_for(:products) { set :model_name, "Producto" } }
    end
    Dami.locale = nil
    Dami.locale = :en
    assert_equal "Producto", Dami.lm(:products, locale: :es)
  end
  
# test/localization_helpers_test.rb
def test_method_tracing
  # Check if methods are the same as what's in the file
  
  # Get the actual method objects
  setter_method = Dami.method(:locale=)
  getter_method = Dami.method(:current_locale)
  
  
  # Check if there are multiple definitions
end
def test_i18n_investigation
  
  if defined?(I18n) && I18n.respond_to?(:locale)
    Dami.locale = "es"
  end
end
def test_locale_setter_accepts_strings_and_symbols
  
  # Test setting a string
  Dami.locale = "es"
  stored_value = Dami.instance_variable_get(:@locale)
  
  # Fix the variable name - change 'current_value' to 'result'
  result = Dami.current_locale
  assert_equal :es, result
  
  # Test setting a symbol
  Dami.locale = :fr
  assert_equal :fr, Dami.current_locale
  
  # Test setting nil
  Dami.locale = nil
  assert_nil Dami.locale
  assert_equal :en, Dami.current_locale
end
end