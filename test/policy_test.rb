# test/policy_test.rb
# frozen_string_literal: true
require_relative 'test_helper'

class PolicyTest < Minitest::Test
    def setup
    super
  end
  def test_validation_failure_on_create
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(status: 'pending')
    end
    assert_includes error.errors[:name], "is required"
    assert_includes error.errors[:status], "is not in the list of accepted values"
  end
  
  def test_validation_failure_on_update
    user = @db[:users].create(name: 'Valid User', status: 'active')
    assert_raises(Dami::ValidationError) do
      @db[:users].where(id: user[:id]).update(status: 'pending')
    end
  end
  
  def test_optional_field_with_format_validation_passes_when_nil
    user = @db[:users].create(name: 'Test', status: 'active', role: nil, permit: [:role])
    assert user[:id]
    assert_nil user[:role]
  end
  
  def test_partial_update_succeeds_without_unrelated_validations
    user = @db[:users].create(name: 'Valid User', status: 'active')
    @db[:users].where(id: user[:id]).update(name: 'New Name')
    updated_user = @db[:users].find(user[:id])
    assert_equal 'New Name', updated_user[:name]
  end
  
  def test_protection_failure_on_create
    assert_raises(Dami::ProtectionError) do
      @db[:users].create(name: 'Admin', role: 'admin', status: 'active')
    end
  end
  
  def test_protection_failure_on_update
    user = @db[:users].create(name: 'Normal User', status: 'active')
    assert_raises(Dami::ProtectionError) do
      @db[:users].where(id: user[:id]).update(role: 'admin')
    end
    refreshed_user = @db[:users].find(user[:id])
    assert_nil refreshed_user[:role]
  end
  
  def test_permit_success_on_create
    user = @db[:users].create(name: 'Admin', role: 'admin', status: 'active', permit: [:role])
    assert_equal 'admin', user[:role]
  end
  
  def test_permit_success_on_update
    user = @db[:users].create(name: 'Normal User', status: 'active')
    @db[:users].where(id: user[:id]).update(role: 'moderator', permit: [:role])
    updated_user = @db[:users].find(user[:id])
    assert_equal 'moderator', updated_user[:role]
  end
  
  def test_protect_false_success
    user = @db[:users].create(name: 'Root', role: 'root', status: 'active', protect: false)
    assert_equal 'root', user[:role]
  end
  
  def test_unknown_field_failure_on_create
    assert_raises(Dami::UnknownFieldsError) do
      @db[:users].create(name: 'Hacker', hacked: true, status: 'active')
    end
  end
  
  def test_unknown_field_failure_on_update
    user = @db[:users].create(name: 'Test', status: 'active')
    assert_raises(Dami::UnknownFieldsError) do
      @db[:users].where(id: user[:id]).update(hacked: true)
    end
  end
  
  def test_protect_false_on_update
    user = @db[:users].create(name: 'Test', status: 'active')
    @db[:users].where(id: user[:id]).update(role: 'admin', protect: false)
    updated_user = @db[:users].find(user[:id])
    assert_equal 'admin', updated_user[:role]
  end
  
  def test_protect_false_overrides_permit
    user = @db[:users].create(name: 'Test', role: 'admin', status: 'active', permit: [], protect: false)
    assert_equal 'admin', user[:role]
  end
  
  def test_validation_runs_when_protection_is_disabled
    assert_raises(Dami::ValidationError) do
      @db[:users].create(name: '', status: 'active', role: 'admin', protect: false)
    end
  end
  
  def test_permitting_an_unknown_field_is_still_an_error
    assert_raises(Dami::UnknownFieldsError) do
      @db[:users].create(name: 'Test', status: 'active', bad_field: true, permit: [:bad_field])
    end
  end
  
  def test_update_preserves_protected_value
    user = @db[:users].create(name: 'Admin', role: 'admin', status: 'active', permit: [:role])
    @db[:users].where(id: user[:id]).update(name: 'Admin Updated')
    updated_user = @db[:users].find(user[:id])
    assert_equal 'Admin Updated', updated_user[:name]
    assert_equal 'admin', updated_user[:role]
  end
  
  def test_validation_precedes_protection
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(name: '', role: 'admin', status: 'active')
    end
    assert_includes error.errors[:name], "is required"
  end
  
  def test_empty_create_fails_validation
    assert_raises(Dami::ValidationError) do
      @db[:users].create({})
    end
  end
  
  def test_empty_update_does_nothing
    user = @db[:users].create(name: 'Test', status: 'active')
    @db[:users].where(id: user[:id]).update({})
    updated_user = @db[:users].find(user[:id])
    assert_equal 'Test', updated_user[:name]
  end
  # Add these tests to test/policy_test.rb

def test_model_level_permit
  # Recreate model with permit in protection block
  Dami.model :users do
    fields do
      field :name, :string
      field :role, :string
      field :status, :string
    end
    
    protection do
      permit :status  # Status is always allowed
      protect :role   # Role is protected
    end
    
    validate do
      rule :name, :required
      rule :status, inclusion: %w[active inactive]
    end
  end
  
  # Status can be set without permit (model allows it)
  user = @db[:users].create(name: 'Test', status: 'active')
  assert_equal 'active', user[:status]
  
  # Role still protected
  assert_raises(Dami::ProtectionError) do
    @db[:users].create(name: 'Test', role: 'admin', status: 'active')
  end
end

def test_model_permit_and_call_permit_merge
  Dami.model :users do
    fields do
      field :name, :string
      field :role, :string
      field :status, :string
    end
    
    protection do
      permit :status           # Model allows status
      protect :role, :status   # Both protected (status in both lists)
    end
    
    validate do
      rule :name, :required
      rule :status, inclusion: %w[active inactive]
    end
  end
  
  # Status allowed by model's permit
  user = @db[:users].create(name: 'Test', status: 'active')
  assert_equal 'active', user[:status]
  
  # Role requires call-level permit
  user = @db[:users].create(name: 'Test', role: 'admin', status: 'active', permit: [:role])
  assert_equal 'admin', user[:role]
  
  # Both model permit and call permit work together
  user = @db[:users].create(
    name: 'Test',
    role: 'moderator',
    status: 'inactive',
    permit: [:role]  # Call permits role, model already permits status
  )
  assert_equal 'moderator', user[:role]
  assert_equal 'inactive', user[:status]
end

def test_model_permit_on_update
  Dami.model :users do
    fields do
      field :name, :string
      field :role, :string
      field :status, :string
    end
    
    protection do
      permit :status
      protect :role
    end
    
    validate do
      rule :name, :required
      rule :status, inclusion: %w[active inactive]
    end
  end
  
  user = @db[:users].create(name: 'Test', status: 'active')
  
  # Status can be updated (model permits it)
  @db[:users].where(id: user[:id]).update(status: 'inactive')
  updated = @db[:users].find(user[:id])
  assert_equal 'inactive', updated[:status]
  
  # Role still protected on update
  assert_raises(Dami::ProtectionError) do
    @db[:users].where(id: user[:id]).update(role: 'admin')
  end
  
  # Role can be updated with call-level permit
  @db[:users].where(id: user[:id]).update(role: 'admin', permit: [:role])
  updated = @db[:users].find(user[:id])
  assert_equal 'admin', updated[:role]
end

def test_empty_permit_list_still_protects
  Dami.model :users do
    fields do
      field :name, :string
      field :role, :string
      field :status, :string
    end
    
    protection do
      protect :role
    end
    
    validate do
      rule :name, :required
      rule :status, inclusion: %w[active inactive]
    end
  end
  
  # Protected field fails even with empty permit
  assert_raises(Dami::ProtectionError) do
    @db[:users].create(name: 'Test', role: 'admin', status: 'active', permit: [])
  end
  
  # Must actually permit the field
  user = @db[:users].create(name: 'Test', role: 'admin', status: 'active', permit: [:role])
  assert_equal 'admin', user[:role]
end

def test_model_permit_multiple_fields
  Dami.model :users do
    fields do
      field :name, :string
      field :role, :string
      field :status, :string
    end
    
    protection do
      permit :status, :role  # Both allowed at model level
      protect :status, :role # But also both protected
    end
    
    validate do
      rule :name, :required
      rule :status, inclusion: %w[active inactive]
    end
  end
  
  # Both can be set (model permits them)
  user = @db[:users].create(name: 'Test', role: 'admin', status: 'active')
  assert_equal 'admin', user[:role]
  assert_equal 'active', user[:status]
end
end