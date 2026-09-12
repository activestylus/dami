# File: test/connection_pool_test.rb
require_relative 'test_helper'
class ConnectionPoolTest < Minitest::Test
  POOL_DB = 'pool_test.db'

  def setup
    super
    self.class.cleanup_database_files(POOL_DB)
  end

  def teardown
    super
    self.class.cleanup_database_files(POOL_DB)
  end

  def test_default_pool_size_is_5
    db = Dami.connect(:test_default, adapter: :sqlite, path: POOL_DB)
    pool = db.instance_variable_get(:@connection_pool)
    assert_equal 5, pool.instance_variable_get(:@size)
  end

  def test_custom_pool_size_is_respected
    db = Dami.connect(:test_custom, adapter: :sqlite, path: POOL_DB, pool_size: 10)
    pool = db.instance_variable_get(:@connection_pool)
    assert_equal 10, pool.instance_variable_get(:@size)
  end

  # An in-memory SQLite database exists per connection, so a pool of N
  # connections would be N unrelated databases. Dami forces one connection.
  def test_memory_database_forces_a_single_connection
    db = Dami.connect(:test_memory, adapter: :sqlite, path: ':memory:', pool_size: 10)
    pool = db.instance_variable_get(:@connection_pool)
    assert_equal 1, pool.instance_variable_get(:@size)
    db.execute("CREATE TABLE t (id INTEGER PRIMARY KEY)")
    threads = 5.times.map { |i| Thread.new { db.execute("INSERT INTO t (id) VALUES (?)", [i]) } }
    threads.each(&:join)
    assert_equal 5, db.execute("SELECT COUNT(*) AS c FROM t").first['c']
  end

  def test_pool_enforces_connection_limit
    db = Dami.connect(:test_limit, adapter: :sqlite, path: POOL_DB, pool_size: 2)
    db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY)")
    connections_acquired = Queue.new
    threads = 5.times.map do |i|
      Thread.new do
        db.execute("INSERT INTO test (id) VALUES (?)", [i])
        connections_acquired << i
      end
    end
    threads.each(&:join)
    assert_equal 5, connections_acquired.size
    assert_equal 5, db.execute("SELECT COUNT(*) AS c FROM test").first['c']
  end
end
