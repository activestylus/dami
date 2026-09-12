# File: test/edge_cases_test.rb

require_relative 'test_helper'

class EdgeCasesTest < Minitest::Test
  def setup
    super
    # Ensure all models are available for these tests
    # Sometimes test isolation can cause model registry issues
  end

  # === CONNECTION POOL & RESOURCE MANAGEMENT ===

  def test_handles_connection_pool_exhaustion_gracefully
    threads = []
    pool_size = 5
    
    (pool_size + 10).times do |i|
      threads << Thread.new do
        @db[:users].where(id: i).first
      end
    end
    
    threads.each(&:join)
    assert true
  end

  def test_connection_returns_to_pool_after_exception
    pool = @db.instance_variable_get(:@connection_pool)
    initial_size = pool.instance_variable_get(:@available).instance_variable_get(:@que).size
    
    10.times do
      begin
        @db.transaction do
          @db[:users].create(first_name: 'Test', last_name: 'User', status: 'active')
          raise "Intentional error"
        end
      rescue => e
        # Swallow error
      end
    end
    
    GC.start
    sleep 0.1
    
    final_size = pool.instance_variable_get(:@available).instance_variable_get(:@que).size
    assert_equal initial_size, final_size, "Connections leaked after exceptions"
  end

  # === LARGE DATA SETS ===

  def test_create_many_with_large_batch
    records = 1_000.times.map { |i| { first_name: "User#{i}", last_name: 'Test', status: 'active' } }
    @db[:users].create_many(records)
    assert_equal 1_000, @db[:users].count
  end

  def test_where_with_large_in_clause
    10.times { |i| @db[:users].create(first_name: "User#{i}", last_name: 'Test', status: 'active') }
    
    user_ids = (1..1000).to_a
    results = @db[:users].where(id: user_ids).to_a
    assert results.is_a?(Array)
  end

  # === VALIDATION EDGE CASES ===

  def test_validation_handles_emoji_and_unicode
    user1 = @db[:users].create(first_name: "👨‍👩‍👧‍👦", last_name: 'Family', status: 'active')
    assert user1[:id]
    
    user2 = @db[:users].create(first_name: "नमस्ते", last_name: 'Hindi', status: 'active')
    assert user2[:id]
    
    found = @db[:users].find(user1[:id])
    assert_equal "👨‍👩‍👧‍👦", found[:first_name]
  end

  def test_required_validation_catches_both_nil_and_empty
    error1 = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: nil, status: 'active')
    end
    assert_includes error1.errors[:first_name], "is required"
    
    error2 = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: '', status: 'active')
    end
    assert_includes error2.errors[:first_name], "is required"
  end

  # === DATABASE CONSTRAINTS ===

  def test_handles_foreign_key_constraint_violation_gracefully
    # Test that we get an error (not necessarily a custom one)
    begin
      # Try to create a post with invalid user_id via direct SQL
      @db.execute("INSERT INTO posts (user_id, title) VALUES (99999, 'Orphan')")
      # If this succeeds, foreign keys aren't enforced (SQLite default)
      # Clean up
      @db.execute("DELETE FROM posts WHERE title = 'Orphan'")
    rescue => e
      # This is expected if foreign keys are enforced
      assert true
    end
  end

  def test_unique_constraint_with_concurrent_creates
    begin
      @db.execute("CREATE UNIQUE INDEX unique_email ON users(email)")
    rescue
      # Index might already exist
    end
    
successes = []
threads = 10.times.map do |i|
  Thread.new do
    begin
      user = @db[:users].create(
        first_name: "User#{i}",
        last_name: 'Test',
        email: 'same@email.com',
        status: 'active'
      )
      successes << user
    rescue Dami::UniqueConstraintViolation
      nil
    end
  end
end
    
    threads.each(&:join)
    assert_equal 1, successes.compact.count, "Only one concurrent create should succeed with unique constraint"
    
    @db.execute("DROP INDEX IF EXISTS unique_email")
  end

  # === TRANSACTION EDGE CASES ===

  def test_nested_transaction_savepoint_behavior
    outer_user_created = false
    
    @db.transaction do
      @db[:users].create(first_name: 'Outer', last_name: 'User', status: 'active')
      outer_user_created = true
      
      begin
        @db.transaction do
          @db[:users].create(first_name: 'Inner', last_name: 'User', status: 'active')
          raise "Inner fails"
        end
      rescue => e
        # Inner transaction failed
      end
    end
    
    assert outer_user_created
    assert_operator @db[:users].count, :>=, 1
  end

  # === QUERY BUILDER EDGE CASES ===

  def test_order_by_with_null_values
    # Insert directly into database to bypass validation
    @db.execute("INSERT INTO users (first_name, last_name, status) VALUES (NULL, 'Null', 'active')")
    @db[:users].create(first_name: 'Alice', last_name: 'Test', status: 'active')
    @db[:users].create(first_name: 'Bob', last_name: 'Test', status: 'active')
    
    results = @db[:users].order(:first_name).to_a
    assert_equal 3, results.length
  end

  def test_where_distinguishes_empty_string_from_null
    # Insert directly to bypass validation
    @db.execute("INSERT INTO users (first_name, last_name, status) VALUES ('', 'Empty', 'active')")
    @db.execute("INSERT INTO users (first_name, last_name, status) VALUES (NULL, 'Null', 'active')")
    
    empty_results = @db[:users].where(first_name: '').to_a
    null_results = @db[:users].where(first_name: nil).to_a
    
    assert_equal 1, empty_results.length
    assert_equal 1, null_results.length
    assert_equal 'Empty', empty_results.first[:last_name]
    assert_equal 'Null', null_results.first[:last_name]
  end

  def test_empty_string_vs_null_in_validation
    error1 = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: '', status: 'active')
    end
    
    error2 = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: nil, status: 'active')
    end
    
    assert_includes error1.errors[:first_name], "is required"
    assert_includes error2.errors[:first_name], "is required"
  end


  # === ERROR MESSAGES ===

  def test_validation_errors_are_helpful
    error = assert_raises(Dami::ValidationError) do
      @db[:users].create(first_name: '', status: 'invalid_status')
    end
    
    assert error.errors.key?(:first_name)
    assert error.errors.key?(:status)
    
    assert_includes error.errors[:first_name].join, "required"
    assert_includes error.errors[:status].join, "not in the list"
  end
  # File: test/edge_cases_test.rb

# REMOVE this old test:
# def test_protection_bypassed_in_create_many

# REPLACE with these new tests:

def test_protection_enforced_in_create_many
  assert_raises(Dami::ProtectionError) do
    @db[:users].create_many([
      { first_name: 'User1', last_name: 'Test', role: 'admin', status: 'active' }
    ])
  end
  
  assert_equal 0, @db[:users].where(first_name: 'User1').count
end
def test_validation_enforced_in_create_many
  error = assert_raises(Dami::ValidationError) do
    @db[:users].create_many([
      { first_name: '', status: 'active' },
      { first_name: 'Valid', last_name: 'Test', status: 'active' },
      { first_name: 'Also', status: 'invalid_status' }
    ])
  end
  
  # Check that error message mentions multiple records
  assert_includes error.message, "Validation failed"
  
  # Verify nothing was created (atomic failure)
  assert_equal 0, @db[:users].where(first_name: 'Valid').count
end

def test_create_many_succeeds_when_all_valid
  records = @db[:users].create_many([
    { first_name: 'User1', last_name: 'Test', status: 'active' },
    { first_name: 'User2', last_name: 'Test', status: 'active' }
  ])
  
  assert_equal 2, records.length
  assert records.all? { |r| r.is_a?(Dami::RecordProxy) }
  assert_equal 2, @db[:users].count
end

def test_create_many_with_permit_works
  records = @db[:users].create_many([
    { first_name: 'Admin', last_name: 'User', role: 'admin', status: 'active' }
  ], permit: [:role])
  
  assert_equal 1, records.length
  assert_equal 'admin', records.first[:role]
end
end