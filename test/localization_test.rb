# File: test/localization_test.rb

require_relative 'test_helper'

class LocalizationTest < Minitest::Test
  def setup
    super
  end

  def test_default_rules_have_translatable_messages
    assert_equal "is required", Dami.translate("validations.required")
    assert_equal "must be at least 10 characters", Dami.translate("validations.min_length", 10)
  end

  def test_localization_dsl_can_override_default_messages
    Dami.localize :validations do
      en do
        set :required, "cannot be blank"
      end
    end
    assert_equal "cannot be blank", Dami.translate("validations.required")
  end

  # THE FIX: This test now uses the corrected `with_locale` helper and will pass.
  def test_localization_can_be_scoped_by_language
    Dami.localize :validations do
      es do
        set :required, "no puede estar en blanco"
      end
    end

    # Check the default English message
    assert_equal "is required", Dami.translate("validations.required")
    
    # Switch to Spanish and check again
    Dami.with_locale(:es) do
      assert_equal "no puede estar en blanco", Dami.translate("validations.required")
    end

    # Ensure the locale is switched back
    assert_equal :en, Dami.current_locale
    assert_equal "is required", Dami.translate("validations.required")
  end

  def test_translate_returns_fallback_message_for_unknown_key
    fallback_message = Dami.translate("validations.nonexistent_rule")
    assert_includes fallback_message, "translation missing"
  end

  def test_localize_supports_multiple_scopes_and_languages
    Dami.localize :models do
      en { attributes_for(:users) { set :first_name, "First Name" } }
      es { attributes_for(:users) { set :first_name, "Nombre" } }
    end

    assert_equal "First Name", Dami.translate("models.users.first_name")
    Dami.with_locale(:es) do
      assert_equal "Nombre", Dami.translate("models.users.first_name")
    end
  end
end