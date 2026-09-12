# File: test/policy_test.rb

require_relative 'test_helper'

class PolicyTest < Minitest::Test
  def setup
    super
  end

  def test_validation_failure_on_create
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(status: 'pending')
    end
    assert_includes error.errors[:first_name], "is required"
    assert_includes error.errors[:status], "is not in the list of accepted values"
  end

  def test_validation_failure_on_update
    user = @db[:users].create(first_name: 'Valid', last_name: 'User', status: 'active')
    assert_raises(Dami::ValidationError) do
      @db[:users].where(id: user[:id]).update(status: 'pending')
    end
  end

  def test_optional_field_with_format_validation_passes_when_nil
    user = @db[:users].create(first_name: 'Test', last_name: 'User', status: 'active', role: nil, permit: [:role])
    assert user[:id]
    assert_nil user[:role]
  end

  def test_partial_update_succeeds_without_unrelated_validations
    user = @db[:users].create(first_name: 'Valid', last_name: 'User', status: 'active')
    @db[:users].where(id: user[:id]).update(first_name: 'New First Name')
    updated_user = @db[:users].find(user[:id])
    assert_equal 'New First Name', updated_user[:first_name]
  end

  def test_protection_failure_on_create
    assert_raises(Dami::ProtectionError) do
      @db[:users].create(first_name: 'Admin', last_name: 'User', role: 'admin', status: 'active')
    end
  end

  def test_protection_failure_on_update
    user = @db[:users].create(first_name: 'Normal', last_name: 'User', status: 'active')
    assert_raises(Dami::ProtectionError) do
      @db[:users].where(id: user[:id]).update(role: 'admin')
    end
    refreshed_user = @db[:users].find(user[:id])
    assert_nil refreshed_user[:role]
  end

  def test_permit_success_on_create
    user = @db[:users].create(first_name: 'Admin', last_name: 'User', role: 'admin', status: 'active', permit: [:role])
    assert_equal 'admin', user[:role]
  end

  def test_permit_success_on_update
    user = @db[:users].create(first_name: 'Normal', last_name: 'User', status: 'active')
    @db[:users].where(id: user[:id]).update(role: 'moderator', permit: [:role])
    updated_user = @db[:users].find(user[:id])
    assert_equal 'moderator', updated_user[:role]
  end

  def test_protect_false_success
    user = @db[:users].create(first_name: 'Root', last_name: 'User', role: 'root', status: 'active', protect: false)
    assert_equal 'root', user[:role]
  end

  def test_unknown_field_failure_on_create
    assert_raises(Dami::UnknownFieldsError) do
      @db[:users].create(first_name: 'Hacker', hacked: true, status: 'active')
    end
  end

  def test_unknown_field_failure_on_update
    user = @db[:users].create(first_name: 'Test', status: 'active')
    assert_raises(Dami::UnknownFieldsError) do
      @db[:users].where(id: user[:id]).update(hacked: true)
    end
  end

  def test_protect_false_on_update
    user = @db[:users].create(first_name: 'Test', status: 'active')
    @db[:users].where(id: user[:id]).update(role: 'admin', protect: false)
    updated_user = @db[:users].find(user[:id])
    assert_equal 'admin', updated_user[:role]
  end

  def test_protect_false_overrides_permit
    user = @db[:users].create(first_name: 'Test', role: 'admin', status: 'active', permit: [], protect: false)
    assert_equal 'admin', user[:role]
  end

  def test_validation_runs_when_protection_is_disabled
    assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: '', status: 'active', role: 'admin', protect: false)
    end
  end

  def test_permitting_an_unknown_field_is_still_an_error
    assert_raises(Dami::UnknownFieldsError) do
      @db[:users].create(first_name: 'Test', status: 'active', bad_field: true, permit: [:bad_field])
    end
  end

  def test_update_preserves_protected_value
    user = @db[:users].create(first_name: 'Admin', role: 'admin', status: 'active', permit: [:role])
    @db[:users].where(id: user[:id]).update(first_name: 'Admin Updated')
    updated_user = @db[:users].find(user[:id])
    assert_equal 'Admin Updated', updated_user[:first_name]
    assert_equal 'admin', updated_user[:role]
  end

  def test_validation_precedes_protection
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: '', role: 'admin', status: 'active')
    end
    assert_includes error.errors[:first_name], "is required"
  end

  def test_empty_create_fails_validation
    assert_raises(Dami::ValidationError) do
      @db[:users].create({})
    end
  end

  def test_empty_update_does_nothing
    user = @db[:users].create(first_name: 'Test', status: 'active')
    @db[:users].where(id: user[:id]).update({})
    updated_user = @db[:users].find(user[:id])
    assert_equal 'Test', updated_user[:first_name]
  end

  # ===== RESTORED TESTS FROM OLD VERSION =====

  def test_model_level_permit
    Dami.model :users do
      fields { field :first_name, :string; field :role, :string; field :status, :string }
    end
    Dami.behavior :users do
      validate { rule :first_name, :required; rule :status, inclusion: %w[active inactive] }
      protection { permit :status; protect :role }
    end

    user = @db[:users].create(first_name: 'Test', status: 'active')
    assert_equal 'active', user[:status]

    assert_raises(Dami::ProtectionError) do
      @db[:users].create(first_name: 'Test', role: 'admin', status: 'active')
    end
  end

  def test_model_permit_and_call_permit_merge
    Dami.model :users do
      fields { field :first_name, :string; field :role, :string; field :status, :string }
    end
    Dami.behavior :users do
      protection { permit :status; protect :role, :status }
      validate { rule :first_name, :required; rule :status, inclusion: %w[active inactive] }
    end

    user = @db[:users].create(first_name: 'Test', status: 'active')
    assert_equal 'active', user[:status]

    user = @db[:users].create(first_name: 'Test', role: 'admin', status: 'active', permit: [:role])
    assert_equal 'admin', user[:role]
  end

  def test_model_permit_on_update
    Dami.model :users do
      fields { field :first_name, :string; field :role, :string; field :status, :string }
      
    end
    Dami.behavior :users do
      protection { permit :status; protect :role }
      validate { rule :first_name, :required; rule :status, inclusion: %w[active inactive] }
    end

    user = @db[:users].create(first_name: 'Test', status: 'active')

    @db[:users].where(id: user[:id]).update(status: 'inactive')
    updated = @db[:users].find(user[:id])
    assert_equal 'inactive', updated[:status]

    assert_raises(Dami::ProtectionError) do
      @db[:users].where(id: user[:id]).update(role: 'admin')
    end

    @db[:users].where(id: user[:id]).update(role: 'admin', permit: [:role])
    updated = @db[:users].find(user[:id])
    assert_equal 'admin', updated[:role]
  end

  def test_empty_permit_list_still_protects
    Dami.model :users do
      fields { field :first_name, :string; field :role, :string; field :status, :string }
      
    end
    Dami.behavior :users do
      validate { rule :first_name, :required; rule :status, inclusion: %w[active inactive] }
      protection { protect :role }
    end

    assert_raises(Dami::ProtectionError) do
      @db[:users].create(first_name: 'Test', role: 'admin', status: 'active', permit: [])
    end

    user = @db[:users].create(first_name: 'Test', role: 'admin', status: 'active', permit: [:role])
    assert_equal 'admin', user[:role]
  end

  def test_model_permit_multiple_fields
    Dami.model :users do
      fields { field :first_name, :string; field :role, :string; field :status, :string }
    end
    Dami.behavior :users do
      protection { permit :status, :role; protect :status, :role }
      validate { rule :first_name, :required; rule :status, inclusion: %w[active inactive] }
    end

    user = @db[:users].create(first_name: 'Test', role: 'admin', status: 'active')
    assert_equal 'admin', user[:role]
    assert_equal 'active', user[:status]
  end
end