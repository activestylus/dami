# File: test/guardrails_test.rb

require_relative 'test_helper'

class GuardrailsTest < Minitest::Test
  def setup
    super
  end

  # === TESTING Dami.model GUARDRAILS ===

  def test_model_rejects_validate
    error = assert_raises(Dami::InvalidDSLError) do
      Dami.model :bad_users do
        fields { field :name, :string }
        validate { rule :name, :required }  # ❌ Wrong place
      end
    end
    
    assert_includes error.message, "'validate' is not allowed here"
    assert_includes error.message, "Dami.behavior"
  end

  def test_model_rejects_scope
    error = assert_raises(Dami::InvalidDSLError) do
      Dami.model :bad_users do
        fields { field :name, :string }
        scope :active, -> { where(status: 'active') }  # ❌ Wrong place
      end
    end
    
    assert_includes error.message, "'scope' is not allowed here"
    assert_includes error.message, "Dami.scopes"
  end

  def test_model_rejects_protection
    error = assert_raises(Dami::InvalidDSLError) do
      Dami.model :bad_users do
        fields { field :name, :string }
        protection { protect :role }  # ❌ Wrong place
      end
    end
    
    assert_includes error.message, "'protection' is not allowed here"
    assert_includes error.message, "Dami.behavior"
  end

  # === TESTING Dami.behavior GUARDRAILS ===

  def test_behavior_rejects_fields
    error = assert_raises(Dami::InvalidDSLError) do
      Dami.behavior :users do
        fields { field :name, :string }  # ❌ Wrong place
      end
    end
    
    assert_includes error.message, "'fields' is not allowed here"
    assert_includes error.message, "Dami.model"
  end

  def test_behavior_rejects_scope
    error = assert_raises(Dami::InvalidDSLError) do
      Dami.behavior :users do
        scope :active, -> { where(status: 'active') }  # ❌ Wrong place
      end
    end
    
    assert_includes error.message, "'scope' is not allowed here"
    assert_includes error.message, "Dami.scopes"
  end

  def test_behavior_rejects_relationships
    error = assert_raises(Dami::InvalidDSLError) do
      Dami.behavior :users do
        relationships { has_many :posts }  # ❌ Wrong place
      end
    end
    
    assert_includes error.message, "'relationships' is not allowed here"
    assert_includes error.message, "Dami.model"
  end

  # === TESTING Dami.scopes GUARDRAILS ===

  def test_scopes_rejects_fields
    error = assert_raises(Dami::InvalidDSLError) do
      Dami.scopes :users do
        fields { field :name, :string }  # ❌ Wrong place
      end
    end
    
    assert_includes error.message, "'fields' is not allowed here"
    assert_includes error.message, "Dami.model"
  end

  def test_scopes_rejects_validate
    error = assert_raises(Dami::InvalidDSLError) do
      Dami.scopes :users do
        validate { rule :name, :required }  # ❌ Wrong place
      end
    end
    
    assert_includes error.message, "'validate' is not allowed here"
    assert_includes error.message, "Dami.behavior"
  end

  # === TESTING CORRECT USAGE ===

  def test_correct_separation_works
    # This should all work fine
    Dami.model :correct_users do
      fields { field :first_name, :string; field :status, :string }
    end
    
    Dami.behavior :correct_users do
      validate { rule :first_name, :required }
    end
    
    Dami.scopes :correct_users do
      scope :active, -> { where(status: 'active') }
    end
    
    # Verify it all works
    assert Dami.find_model(:correct_users)
    assert_respond_to @db[:correct_users], :active
  end
end