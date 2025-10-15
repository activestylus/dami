# frozen_string_literal: true
require_relative 'test_helper'

# --- CLASS 1: For tests that need a pre-populated database ---
class PerformanceBatchingTest < Minitest::Test
  def setup
    super
    @db[:users].create_many(Array.new(2500) { |i| { name: "User-#{i}" } })
  end

  def test_find_each_processes_all_records
    processed_count = 0
    @db[:users].find_each(batch_size: 500) do |user|
      processed_count += 1
    end
    assert_equal 2500, processed_count
  end

  def test_find_in_batches_yields_correct_batches
    batch_counts = []
    @db[:users].find_in_batches(batch_size: 1000) do |batch|
      batch_counts << batch.size
    end
    assert_equal [1000, 1000, 500], batch_counts
  end
end
# --- CLASS 2: For tests that must start with a clean, empty database ---
class PerformanceCreationTest < Minitest::Test
  def setup
    @db_path = "perf_creation_test.db"
    self.class.cleanup_database_files(@db_path)
    @db = Dami.connect(:default, adapter: :sqlite, path: @db_path)
    @db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);")
    Dami.model(:users) { fields { field :name, :string } }
  end

  def teardown
    if @db
      pool = @db.instance_variable_get(:@connection_pool)
      pool&.shutdown(&:close)
    end
    self.class.cleanup_database_files(@db_path)
  end

  def test_create_many_is_effective
    records_to_create = Array.new(1000) { |i| { name: "New-User-#{i}" } }
    @db[:users].create_many(records_to_create)

    # This will now pass without the RuntimeError
    assert_equal 1000, @db[:users].count
  end

  def test_create_many_is_effective
    records_to_create = Array.new(1000) { |i| { name: "New-User-#{i}" } }
    @db[:users].create_many(records_to_create)

    assert_equal 1000, @db[:users].count
  end
end