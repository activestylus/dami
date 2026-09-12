# test/virtual_fields_test.rb
require_relative 'test_helper'

class VirtualFieldsTest < Minitest::Test
  def setup
    super
  end

  # Test 1: Virtual fields accepted as input
  def test_virtual_fields_accepted
    Dami.model :users do
      fields { field :email, :string; field :password_hash, :string }
      virtual { field :password, :string; field :password_confirmation, :string }
    end
    Dami.behavior :users do
      validate { rule :email, :required }
    end
    
    user = @db[:users].create(
      email: 'test@example.com',
      password: 'secret123',
      password_confirmation: 'secret123'
    )
    
    assert user[:id]
    assert_equal 'test@example.com', user[:email]
  end

  # Test 2: Virtual fields filtered from database
  def test_virtual_fields_not_in_database
    Dami.model :users do
      fields { field :email, :string }
      virtual { field :password, :string }
    end
    
    user = @db[:users].create(
      email: 'test@example.com',
      password: 'secret123'
    )
    
    db_record = @db.execute("SELECT * FROM users WHERE id = ?", [user[:id]]).first
    refute db_record.key?('password'), "Virtual field should not be in database"
    refute db_record.key?(:password), "Virtual field should not be in database"
  end

  # Test 3: Virtual fields can be validated
  def test_virtual_fields_validated
    Dami.model :users do
      fields { field :email, :string }
      virtual { field :password, :string }
    end
    Dami.behavior :users do
      validate { rule :password, :required, min_length: 8 }
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(email: 'test@example.com', password: 'short')
    end
    
    assert_includes error.errors[:password], "must be at least 8 characters"
  end

  # Test 4: Conditional validation with 'when:'
  def test_conditional_when
    Dami.model :users do
      fields { field :email, :string; field :account_type, :string; field :ssn, :string }
    end
    Dami.behavior :users do
      validate do
        rule :email, :required
        rule :ssn, :required, when: { account_type: 'business' }
      end
    end
    
    user1 = @db[:users].create(
      email: 'personal@example.com',
      account_type: 'personal'
    )
    assert user1[:id]
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(
        email: 'business@example.com',
        account_type: 'business'
      )
    end
    assert_includes error.errors[:ssn], "is required"
    
    user2 = @db[:users].create(
      email: 'business@example.com',
      account_type: 'business',
      ssn: '123-45-6789'
    )
    assert user2[:id]
  end

  # Test 5: Conditional validation with 'unless:'
  def test_conditional_unless
    Dami.model :users do
      fields { field :email, :string; field :account_type, :string; field :ssn, :string }
    end
    Dami.behavior :users do
      validate do
        rule :email, :required
        rule :ssn, :required, unless: { account_type: 'personal' }
      end
    end
    
    user = @db[:users].create(
      email: 'test@example.com',
      account_type: 'personal'
    )
    assert user[:id]
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(
        email: 'test@example.com',
        account_type: 'business'
      )
    end
    assert_includes error.errors[:ssn], "is required"
  end

  # Test 6: Conditional validation with 'if:' lambda
  def test_conditional_if_lambda
    Dami.model :users do
      fields { field :email, :string; field :account_type, :string; field :ssn, :string }
    end
    Dami.behavior :users do
      validate do
        rule :email, :required
        rule :ssn, :required, if: ->(attrs) { 
          attrs[:account_type] == 'business' && attrs[:email]&.include?('@company.com')
        }
      end
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(
        email: 'admin@company.com',
        account_type: 'business'
      )
    end
    assert_includes error.errors[:ssn], "is required"
    
    user = @db[:users].create(
      email: 'admin@gmail.com',
      account_type: 'business'
    )
    assert user[:id]
  end

  # Test 7: Virtual field with conditional validation
  def test_virtual_field_with_conditional
    Dami.model :users do
      fields { field :email, :string; field :account_type, :string }
      virtual { field :terms_accepted, :boolean }
    end
    Dami.behavior :users do
      validate do
        rule :email, :required
        rule :terms_accepted, :required, when: { account_type: 'personal' }
      end
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(
        email: 'test@example.com',
        account_type: 'personal'
      )
    end
    assert_includes error.errors[:terms_accepted], "is required"
    
    user = @db[:users].create(
      email: 'test@example.com',
      account_type: 'personal',
      terms_accepted: true
    )
    assert user[:id]
    
    user2 = @db[:users].create(
      email: 'biz@example.com',
      account_type: 'business'
    )
    assert user2[:id]
  end

  # Test 8: Multiple conditionals on same field
  def test_multiple_conditionals
    Dami.model :users do
      fields { field :email, :string; field :account_type, :string; field :ssn, :string }
    end
    Dami.behavior :users do
      validate do
        rule :email, :required
        rule :ssn, :required, when: { account_type: 'business' }
        rule :ssn, format: /^\d{3}-\d{2}-\d{4}$/, if: ->(attrs) { attrs[:ssn] }
      end
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(
        email: 'test@example.com',
        account_type: 'business',
        ssn: 'invalid'
      )
    end
    
    assert_includes error.errors[:ssn], "has invalid format"
  end

  # Test 9: Virtual fields on update
  def test_virtual_fields_on_update
    Dami.model :users do
      fields { field :email, :string }
      virtual { field :password, :string }
    end
    Dami.behavior :users do
      validate do
        on :update do
          rule :password, min_length: 8
        end
      end
    end
    
    user = @db[:users].create(email: 'test@example.com')
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].where(id: user[:id]).update(password: 'short')
    end
    assert_includes error.errors[:password], "must be at least 8 characters"
    
    @db[:users].where(id: user[:id]).update(password: 'LongPassword123')
    
    db_record = @db.execute("SELECT * FROM users WHERE id = ?", [user[:id]]).first
    refute db_record.key?('password')
  end

  # Test 10: Conditional only applies to specified operation
  def test_conditional_with_operation_context
    Dami.model :users do
      fields { field :email, :string; field :ssn, :string }
    end
    Dami.behavior :users do
      validate do
        rule :email, :required
        
        on :create do
          rule :ssn, :required, when: { email: 'admin@example.com' }
        end
      end
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(email: 'admin@example.com')
    end
    assert_includes error.errors[:ssn], "is required"
    
    user = @db[:users].create(email: 'admin@example.com', ssn: '123-45-6789')
    assert user[:id]
    
    @db[:users].where(id: user[:id]).update(email: 'newemail@example.com')
    updated = @db[:users].find(user[:id])
    assert_equal 'newemail@example.com', updated[:email]
  end
end