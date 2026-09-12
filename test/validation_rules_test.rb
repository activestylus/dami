require_relative 'test_helper'

class LocalizationAndRulesTest < Minitest::Test
  def setup
    super
    # The main test_helper's `Dami.clear_all!` and subsequent
    # `register_default_rules!` ensures a clean slate with default
    # English messages loaded before every test.
  end

  # --- Section 1: Validation Rule Registration ---
  # This test ports the coverage from the old `test_register_default_rules_creates_all_rules`.
  def test_register_default_rules_populates_the_registry
    # This test confirms that the logic for the rules themselves is still loaded correctly.
    registry = Dami.validation_registry
    assert registry.get(:required)
    assert registry.get(:email)
    assert registry.get(:inclusion)
    assert registry.get(:format)
    assert registry.get(:min_length)
  end

  # --- Section 2: Default Message Translation ---
  # These tests replace the old `test_register_default_rules_creates_all_messages`
  # and `test_rule_message...` tests, using the new `Dami.translate` API.

  def test_translate_fetches_default_static_message
    assert_equal "is required", Dami.translate("validations.required")
    assert_equal "must be valid email", Dami.translate("validations.email")
  end

  def test_translate_fetches_default_dynamic_message
    assert_equal "must be at least 10 characters", Dami.translate("validations.min_length", 10)
  end

  def test_translate_returns_fallback_for_unknown_key
    fallback = Dami.translate("validations.nonexistent_rule")
    assert_includes fallback, "translation missing: en.validations.nonexistent_rule"
  end

  # --- Section 3: Localization and Overriding ---
  # These tests replace the old `test_override_messages...` tests.

  def test_localize_can_override_a_static_message
    Dami.localize :validations do
      en do
        set :required, "cannot be blank, my friend"
      end
    end
    assert_equal "cannot be blank, my friend", Dami.translate("validations.required")
  end

  def test_localize_can_override_a_dynamic_message
    Dami.localize :validations do
      en do
        set :min_length, ->(min) { "is too short (min #{min})" }
      end
    end
    assert_equal "is too short (min 5)", Dami.translate("validations.min_length", 5)
  end

  def test_localization_can_be_scoped_by_language
    Dami.localize :validations do
      es do
        set :required, "no puede estar en blanco"
      end
    end

    assert_equal "is required", Dami.translate("validations.required") # Still defaults to English
    
    Dami.with_locale(:es) do
      assert_equal "no puede estar en blanco", Dami.translate("validations.required")
    end

    assert_equal :en, Dami.current_locale # Ensure locale is restored
    assert_equal "is required", Dami.translate("validations.required")
  end
  
  # --- Section 4: Integration with Validation System ---
  # These tests port the coverage from the old `test_..._work_with_validation_system` tests.

  def test_validation_system_uses_default_message
    Dami.model(:test_users) { fields { field :first_name, :string; field :email, :string } }
    Dami.behavior(:test_users) { validate { rule :first_name, :required; rule :email, :email } }

    error = assert_raises(Dami::ValidationError) do
      @db[:test_users].create(first_name: '', email: 'bad-email')
    end
    
    assert_includes error.errors[:first_name], "is required"
    assert_includes error.errors[:email], "must be valid email"
  end

  def test_validation_system_uses_overridden_message
    Dami.localize :validations do
      en { set :required, "This field is mandatory." }
    end

    Dami.model(:test_users2) { fields { field :first_name, :string } }
    Dami.behavior(:test_users2) { validate { rule :first_name, :required } }

    error = assert_raises(Dami::ValidationError) do
      @db[:test_users2].create(first_name: '')
    end
    
    assert_includes error.errors[:first_name], "This field is mandatory."
  end
  
  def test_validation_system_uses_overridden_dynamic_message
    Dami.localize :validations do
      en { set :min_length, ->(min) { "way too short (needs #{min})" } }
    end
    
    Dami.model(:test_users3) { fields { field :bio, :string } }
    Dami.behavior(:test_users3) { validate { rule :bio, min_length: 10 } }

    error = assert_raises(Dami::ValidationError) do
      @db[:test_users3].create(bio: 'short')
    end
    assert_includes error.errors[:bio], "way too short (needs 10)"
  end
end
