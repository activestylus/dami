# test/validation_registry_test.rb
require_relative 'test_helper'

class ValidationRegistryTest < Minitest::Test
  def setup
    super
    Dami.model :users do
      fields do
        field :name, :string
        field :email, :string
        field :age, :integer
        field :status, :string
        field :role, :string
        field :password_hash, :string # Corrected from :password
      end
      virtual do
        field :password, :string
      end
    end
    
  end
  
  def teardown
    # Handled by test_helper
  end
  
  # Test 1: Basic symbol rules
  def test_symbol_rules
    Dami.model :users do
      fields do
        field :name, :string
        field :email, :string
      end
      
      validate do
        rule :name, :required
        rule :email, :required, :email
      end
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(name: "", email: "invalid")
    end
    
    assert_includes error.errors[:name], "is required"
    assert_includes error.errors[:email], "must be valid email"
    
    user = @db[:users].create(name: "John", email: "john@example.com")
    assert user[:id]
  end
  
  # Test 2: Keyword argument syntax
  def test_keyword_argument_rules
    Dami.model :users do
      fields do
        field :status, :string
        field :role, :string
      end
      
      validate do
        rule :status, inclusion: %w[active inactive]
        rule :role, format: /^(admin|user)$/
      end
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(status: 'pending', role: 'hacker')
    end
    
    assert_includes error.errors[:status], "is not in the list of accepted values"
    assert_includes error.errors[:role], "has invalid format"
    
    user = @db[:users].create(status: 'active', role: 'admin')
    assert user[:id]
  end
  
  # Test 3: Operation context (on :create, on :update)
  def test_operation_context
    Dami.model :users do
      fields do
        field :name, :string
        field :age, :integer
        field :email, :string
      end
      
      validate do
        rule :name, :required
        
        on :create do
          rule :age, :required
          rule :email, :required
        end
      end
    end
    
    # Age required on create
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(name: 'Alice')
    end
    assert_includes error.errors[:age], "is required"
    
    # Create with all required fields
    user = @db[:users].create(name: 'Alice', age: 30, email: 'alice@example.com')
    assert user[:id]
    
    # Age not required on update
    @db[:users].where(id: user[:id]).update(name: 'Alicia')
    updated = @db[:users].find(user[:id])
    assert_equal 'Alicia', updated[:name]
  end
  
  # Test 4: Bulk field operations (all except:)
  def test_all_except
    Dami.model :users do
      fields do
        field :name, :string
        field :email, :string
        field :age, :integer
      end
      
      validate do
        all except: [:age] do
          rule :required
        end
      end
    end
    
    # Name and email required, age optional
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(age: 25)
    end
    
    assert_includes error.errors[:name], "is required"
    assert_includes error.errors[:email], "is required"
    
    user = @db[:users].create(name: 'Bob', email: 'bob@example.com')
    assert user[:id]
    assert_nil user[:age]
  end
  
  # Test 5: Bulk field operations (all only:)
  def test_all_only
    Dami.model :users do
      fields do
        field :name, :string
        field :email, :string
        field :age, :integer
      end
      
      validate do
        all only: [:name, :email] do
          rule :required
        end
      end
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(age: 30)
    end
    
    assert_includes error.errors[:name], "is required"
    assert_includes error.errors[:email], "is required"
  end
  
  # Test 6: Parameterized rules
  def test_parameterized_rules
    Dami.rules :default, {
      min_length: ->(min) {
        { 
          check: ->(v) { v.to_s.length >= min }, 
          message: "must be at least #{min} characters" 
        }
      }
    }
    
    Dami.model :users do
      fields do
        field :name, :string
      end
      
      validate do
        rule :name, [:min_length, 3]
      end
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(name: 'Jo')
    end
    
    assert_includes error.errors[:name], "must be at least 3 characters"
    
    user = @db[:users].create(name: 'John')
    assert user[:id]
  end
  
  # Test 7: Mixed context and bulk operations
  def test_complex_validation_block
    Dami.model :users do
      fields do
        field :name, :string
        field :email, :string
        field :age, :integer
        field :status, :string
      end
      
      validate do
        rule :status, inclusion: %w[active inactive]
        
        on :create do
          all except: [:age] do
            rule :required
          end
        end
        
        on :update do
          rule :name, :required
        end
      end
    end
    
    # On create: name, email, status required (not age)
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(age: 25)
    end
    
    assert_includes error.errors[:name], "is required"
    assert_includes error.errors[:email], "is required"
    assert_includes error.errors[:status], "is required"
    
    # Create succeeds with required fields
    user = @db[:users].create(name: 'Alice', email: 'alice@example.com', status: 'active')
    assert user[:id]
    
    # On update: only name required
    @db[:users].where(id: user[:id]).update(name: 'Alicia', email: 'newemail@example.com')
    updated = @db[:users].find(user[:id])
    assert_equal 'Alicia', updated[:name]
  end
  
  # Test 8: Multiple operations in one context
  def test_multiple_operations
    Dami.model :users do
      fields do
        field :name, :string
        field :status, :string
      end
      
      validate do
        rule :name, :required
        
        on :update do
          rule :status, :required
        end
      end
    end
    
    # Create user (name required always, status not required on create)
    user = @db[:users].create(name: 'Test')
    assert user[:id]
    
    # Status required on update
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
    
    # Recreate model with the correct physical and virtual fields
    Dami.model :users do
      fields do
        field :password_hash, :string # The real database column
      end
      virtual do
        field :password, :string # The field for input and validation
      end
      validate do
        rule :password, :strong_password
      end
    end
    
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(password: 'weak')
    end
    
    assert_includes error.errors[:password], "needs 8+ chars, uppercase, and number"
    
    # THE FIX: Provide data for at least one physical field.
    # We pass the virtual field for validation and a physical field to be saved.
    user = @db[:users].create(password: 'Strong123', password_hash: 'some-placeholder-hash')
    
    # This will now pass because `user` is a valid record proxy.
    assert user[:id]
  end
  
  # Test 10: Rule priority and ordering
  def test_multiple_rules_on_same_field
    Dami.model :users do
      fields do
        field :email, :string
      end
      
      validate do
        rule :email, :required, :email
      end
    end
    
    # Both validations should run
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(email: '')
    end
    
    # Should have at least the required error
    assert_includes error.errors[:email], "is required"
  end
  def test_all_with_kwargs_simple
  Dami.model :users do
    fields do
      field :name, :string
      field :email, :string
      field :age, :integer
    end
    
    validate do
      # Simple: apply presence to all except age
      all except: :age, presence: true
    end
  end
  
  error = assert_raises(Dami::ValidationError) do
    @db[:users].create(age: 25)
  end
  
  assert_includes error.errors[:name], "is required"
  assert_includes error.errors[:email], "is required"
  refute error.errors[:age]
end

def test_all_with_kwargs_only
  Dami.model :users do
    fields do
      field :name, :string
      field :email, :string
    end
    
    validate do
      all only: :email, email: true
    end
  end
  
  error = assert_raises(Dami::ValidationError) do
    @db[:users].create(name: 'John', email: 'invalid')
  end
  
  assert_includes error.errors[:email], "must be valid email"
  refute error.errors[:name]
end

def test_all_with_block_terse_syntax
  Dami.rules :default, {
    max_length: ->(max) {
      {
        check: ->(v) { v.to_s.length <= max },
        message: "cannot exceed #{max} characters"
      }
    }
  }
  
  Dami.model :users do
    fields do
      field :name, :string
      field :email, :string
    end
    
    validate do
      all only: [:name, :email] do
        rule :presence
        rule [:max_length, 50]
      end
    end
  end
  
  # Too long
  error = assert_raises(Dami::ValidationError) do
    @db[:users].create(name: 'a' * 51, email: 'test@example.com')
  end
  
  assert_includes error.errors[:name], "cannot exceed 50 characters"
  
  # Missing
  error = assert_raises(Dami::ValidationError) do
    @db[:users].create(name: '', email: '')
  end
  
  assert_includes error.errors[:name], "is required"
  assert_includes error.errors[:email], "is required"
end

def test_all_block_with_format
  Dami.model :users do
    fields do
      field :username, :string
      field :slug, :string
    end
    
    validate do
      all only: [:username, :slug] do
        rule :presence
        rule format: /^[a-z0-9_]+$/
      end
    end
  end
  
  error = assert_raises(Dami::ValidationError) do
    @db[:users].create(username: 'Invalid User!', slug: 'test')
  end
  
  assert_includes error.errors[:username], "has invalid format"
end

def test_all_kwargs_with_operation_context
  Dami.model :users do
    fields do
      field :name, :string
      field :email, :string
      field :age, :integer
    end
    
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
  
  assert_includes error.errors[:name], "is required"
  
  # Create with fields succeeds
  user = @db[:users].create(name: 'John', email: 'john@example.com')
  assert user[:id]
  
  # Update without fields succeeds (rule only on create)
  @db[:users].where(id: user[:id]).update(name: '')
  updated = @db[:users].find(user[:id])
  assert_equal '', updated[:name]
end
end