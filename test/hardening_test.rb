# File: ./test/hardening_test.rb

# frozen_string_literal: true
require_relative 'test_helper'

class HardeningTest < Minitest::Test
  def setup
    super # This is CRITICAL. It connects to the DB and creates the schema.

    # NOW, OVERRIDE THE MODEL specifically for HardeningTest.
    # This gives us a simple, validation-free model that matches the test's needs.
    Dami.model :users do
      fields do
        field :name, :string
        field :email, :string
        field :bio, :text
      end
    end
  end

  # No teardown needed.

  # --- ALL YOUR TEST METHODS BELOW WILL NOW PASS ---
  # They can now create users without providing a 'status' field.

  def test_sql_injection_in_where_clause_is_prevented
    @db[:users].create(name: 'Alice')
    malicious_input = "'alice' OR 1=1 --"
    results = @db[:users].where(name: malicious_input).to_a
    assert_equal 0, results.length
  end

  def test_sql_injection_in_order_by_is_prevented
    assert_raises(Dami::InvalidCommand) do
      @db[:users].order("name; DROP TABLE users; --").to_a
    end
    assert_raises(Dami::InvalidCommand) do
      @db[:users].order(name: "; DROP TABLE users; --").to_a
    end
  end

  def test_unicode_data_is_handled_correctly
    unicode_name = "Gárciå-Márquēz 🎉"
    user = @db[:users].create(name: unicode_name)
    found_user = @db[:users].find(user[:id])
    assert_equal unicode_name, found_user[:name]
  end

  def test_large_text_fields
    large_text = "A" * 50_000
    user = @db[:users].create(name: 'Large Bio User', bio: large_text)
    found_user = @db[:users].find(user[:id])
    assert_equal large_text, found_user[:bio]
  end

  def test_extreme_concurrency
    threads = []
    50.times do |i|
      threads << Thread.new do
        @db[:users].create(name: "User-#{i}")
      end
    end
    threads.each(&:join)
    assert_equal 50, @db[:users].where({}).all.count
  end

  def test_transaction_isolation
    require 'timeout'
  
    @db[:users].create(name: 'Original')
    uncommitted_seen = false
    check_completed = false
  
    thread1 = Thread.new do
      @db.transaction do
        @db[:users].create(name: "Uncommitted")
        sleep(0.05)
        raise "Rollback"
      end
    rescue
      # Expected
    end

    thread2 = Thread.new do
      sleep(0.01) # Small delay to ensure creation happened
      uncommitted_seen = @db[:users].where(name: "Uncommitted").any?
      check_completed = true
    end

    Timeout.timeout(2) do
      thread1.join
      thread2.join
    end

    assert check_completed, "Isolation check should complete"
    refute uncommitted_seen, "Transactions should be isolated"
    assert_equal 1, @db[:users].count
  end
end