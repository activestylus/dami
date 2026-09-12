# test/validation_registry_test.rb
require_relative 'test_helper'

class ValidationRegistryTest < Minitest::Test
  def setup
    super
  end

  # Test 1: Basic symbol rules
  def test_symbol_rules
    Dami.model :users do
      fields { field :first_name, :string; field :email, :string }
    end
    Dami.behavior :users do
      validate do
        rule :first_name, :required
        rule :email, :required, :email
      end
    end

    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: "", email: "invalid")
    end
    assert_includes error.errors[:first_name], "is required"
    assert_includes error.errors[:email], "must be valid email"

    user = @db[:users].create(first_name: "John", email: "john@example.com")
    assert user[:id]
  end

  # Test 2: Keyword argument syntax
  def test_keyword_argument_rules
    Dami.model :users do
      fields { field :status, :string; field :role, :string; field :first_name, :string }
    end
    Dami.behavior :users do
      validate do
        rule :status, inclusion: %w[active inactive]
        rule :role, format: /^(admin|user)$/
      end
    end

    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: "Test", status: 'pending', role: 'hacker')
    end
    assert_includes error.errors[:status], "is not in the list of accepted values"
    assert_includes error.errors[:role], "has invalid format"

    user = @db[:users].create(first_name: "Test", status: 'active', role: 'admin')
    assert user[:id]
  end

  # Test 3: Operation context (on :create, on :update)
  def test_operation_context
    Dami.model :users do
      fields { field :first_name, :string; field :age, :integer; field :email, :string }
    end
    Dami.behavior :users do
      validate do
        rule :first_name, :required
        on :create do
          rule :age, :required
          rule :email, :required
        end
      end
    end

    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: 'Alice')
    end
    assert_includes error.errors[:age], "is required"

    user = @db[:users].create(first_name: 'Alice', age: 30, email: 'alice@example.com')
    assert user[:id]

    @db[:users].where(id: user[:id]).update(first_name: 'Alicia')
    updated = @db[:users].find(user[:id])
    assert_equal 'Alicia', updated[:first_name]
  end

  # Test 4: Bulk field operations (all except:)
  def test_all_except
    Dami.model :users do
      fields { field :first_name, :string; field :email, :string; field :age, :integer }
    end
    Dami.behavior :users do
      validate do
        all except: [:age] do
          rule :required
        end
      end
    end

    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(age: 25)
    end
    assert_includes error.errors[:first_name], "is required"
    assert_includes error.errors[:email], "is required"

    user = @db[:users].create(first_name: 'Bob', email: 'bob@example.com')
    assert user[:id]
    assert_nil user[:age]
  end

  # Test 5: Bulk field operations (all only:)
  def test_all_only
    Dami.model :users do
      fields { field :first_name, :string; field :email, :string; field :age, :integer }
    end
    Dami.behavior :users do
      validate do
        all only: [:first_name, :email] do
          rule :required
        end
      end
    end

    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(age: 30)
    end
    assert_includes error.errors[:first_name], "is required"
    assert_includes error.errors[:email], "is required"
  end

  # Test 6: Parameterized rules
  def test_parameterized_rules
    Dami.rules(:default, { min_length: ->(min) { { check: ->(v) { v.to_s.length >= min }, message: "must be at least #{min} characters" } } })
    Dami.model(:users) { fields { field :first_name, :string } }
    Dami.behavior(:users) { validate { rule :first_name, [:min_length, 3] } }

    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: 'Jo')
    end
    assert_includes error.errors[:first_name], "must be at least 3 characters"
    
    user = @db[:users].create(first_name: 'John')
    assert user[:id]
  end

  # Test 7: Complex validation block
  def test_complex_validation_block
    Dami.model :users do
      fields { field :first_name, :string; field :email, :string; field :age, :integer; field :status, :string }
    end
    Dami.behavior :users do
      validate do
        rule :status, inclusion: %w[active inactive]
        on :create do
          all except: [:age] do
            rule :required
          end
        end
        on :update do
          rule :first_name, :required
        end
      end
    end

    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(age: 25)
    end
    assert_includes error.errors[:first_name], "is required"
    assert_includes error.errors[:email], "is required"

    user = @db[:users].create(first_name: 'Alice', email: 'alice@example.com', status: 'active')
    assert user[:id]
    
    @db[:users].where(id: user[:id]).update(first_name: 'Alicia', email: 'new@email.com')
    updated = @db[:users].find(user[:id])
    assert_equal 'Alicia', updated[:first_name]
  end

  # Test 8: Multiple operations in one context
  def test_multiple_operations
    Dami.model :users do
      fields { field :first_name, :string; field :status, :string }
    end
    Dami.behavior :users do
      validate do
        rule :first_name, :required
        on :update do
          rule :status, :required
        end
      end
    end

    user = @db[:users].create(first_name: 'Test')
    assert user[:id]
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].where(id: user[:id]).update(status: '')
    end
    assert_includes error.errors[:status], "is required"
  end

  # Test 9: Custom rule registration
  def test_custom_rule_registration
    Dami.rules :default, {
      strong_password: { 
        check: ->(v) { v.to_s.length >= 8 && v =~ /[A-Z]/ && v =~ /[0-9]/ }, 
        message: "needs 8+ chars, uppercase, and number" 
      }
    }
    
    Dami.model :users do
      fields { field :password_hash, :string }
      virtual { field :password, :string }
    end
    Dami.behavior :users do
      validate { rule :password, :strong_password }
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(password: 'weak')
    end
    assert_includes error.errors[:password], "needs 8+ chars, uppercase, and number"
    
    user = @db[:users].create(password: 'Strong123', password_hash: 'some-placeholder-hash')
    assert user[:id]
  end

  # Test 10: Multiple rules on same field
  def test_multiple_rules_on_same_field
    Dami.model :users do
      fields { field :email, :string }
    end
    Dami.behavior :users do
      validate { rule :email, :required, :email }
    end

    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(email: '')
    end
    assert_includes error.errors[:email], "is required"
  end

  # ===== RESTORED TESTS FROM OLD VERSION =====

  # Test 11: All with kwargs simple
  def test_all_with_kwargs_simple
    Dami.model :users do
      fields { field :first_name, :string; field :email, :string; field :age, :integer }
    end
    Dami.behavior :users do
      validate do
        all except: :age, presence: true
      end
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(age: 25)
    end
    
    assert_includes error.errors[:first_name], "is required"
    assert_includes error.errors[:email], "is required"
    refute error.errors[:age]
  end

  # Test 12: All with kwargs only
  def test_all_with_kwargs_only
    Dami.model :users do
      fields { field :first_name, :string; field :email, :string }
    end
    Dami.behavior :users do
      validate do
        all only: :email, email: true
      end
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: 'John', email: 'invalid')
    end
    
    assert_includes error.errors[:email], "must be valid email"
    refute error.errors[:first_name]
  end

  # Test 13: All block with format
  def test_all_block_with_format
    Dami.rules :default, {
      max_length: ->(max) {
        {
          check: ->(v) { v.to_s.length <= max },
          message: "cannot exceed #{max} characters"
        }
      }
    }
    
    Dami.model :users do
      fields { field :first_name, :string; field :email, :string }
    end
    Dami.behavior :users do
      validate do
        all only: [:first_name, :email] do
          rule :presence
          rule [:max_length, 50]
        end
      end
    end
    
    # Too long
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: 'a' * 51, email: 'test@example.com')
    end
    assert_includes error.errors[:first_name], "cannot exceed 50 characters"
    
    # Missing
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: '', email: '')
    end
    assert_includes error.errors[:first_name], "is required"
    assert_includes error.errors[:email], "is required"
  end

  # Test 14: All kwargs with operation context
  def test_all_kwargs_with_operation_context
    Dami.model :users do
      fields { field :first_name, :string; field :email, :string; field :age, :integer }
    end
    Dami.behavior :users do
      validate do
        on :create do
          all except: :age, presence: true
        end
      end
    end
    
    # Create without fields fails
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(age: 30)
    end
    assert_includes error.errors[:first_name], "is required"
    
    # Create with fields succeeds
    user = @db[:users].create(first_name: 'John', email: 'john@example.com')
    assert user[:id]
    
    # Update without fields succeeds (rule only on create)
    @db[:users].where(id: user[:id]).update(first_name: '')
    updated = @db[:users].find(user[:id])
    assert_equal '', updated[:first_name]
  end
end