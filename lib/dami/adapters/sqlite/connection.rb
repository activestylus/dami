# File: lib/dami/adapters/sqlite/connection.rb
require 'connection_pool'
module SqliteConnection
  def connect
    path = @config[:path].to_s
    pool_size = @config[:pool_size] || 5
    # An in-memory database exists per connection, so a pool of N connections
    # would be N unrelated databases. Force a single connection for ':memory:'.
    pool_size = 1 if path == ':memory:'
    @connection_pool ||= ConnectionPool.new(size: pool_size, timeout: 5) do
      SQLite3::Database.new(path).tap do |db|
        db.results_as_hash = true
        db.busy_timeout = 5000
        db.execute("PRAGMA journal_mode = WAL;") unless path == ':memory:'
        db.execute("PRAGMA synchronous = NORMAL;")
        db.execute("PRAGMA foreign_keys = ON;")
        db.instance_variable_set(:@statement_cache, {})
      end
    end
    self
  end

  # Runs the block in a transaction on one pooled connection.
  # Nested calls on the same thread become SAVEPOINTs, so an inner failure
  # rolls back only its own writes and an outer failure rolls back everything.
  def transaction(&block)
    @connection_pool.with do |conn|
      if conn.transaction_active?
        depth = (Thread.current[:dami_savepoint_depth] || 0) + 1
        Thread.current[:dami_savepoint_depth] = depth
        savepoint = "dami_sp_#{depth}"
        conn.execute("SAVEPOINT #{savepoint}")
        begin
          result = yield
          conn.execute("RELEASE SAVEPOINT #{savepoint}")
          result
        rescue ::Exception
          conn.execute("ROLLBACK TO SAVEPOINT #{savepoint}")
          conn.execute("RELEASE SAVEPOINT #{savepoint}")
          raise
        ensure
          Thread.current[:dami_savepoint_depth] = depth - 1
        end
      else
        conn.transaction do
          begin
            Thread.current[:dami_sqlite_connection] = conn
            yield
          ensure
            Thread.current[:dami_sqlite_connection] = nil
          end
        end
      end
    end
  rescue SQLite3::Exception => e
    handle_sqlite_error(e)
  end

  def execute(sql, params = [])
    params = convert_params(params)
    conn = Thread.current[:dami_sqlite_connection]
    conn ? conn.execute(sql, params) : @connection_pool.with { |c| c.execute(sql, params) }
  rescue SQLite3::Exception => e
    handle_sqlite_error(e, sql: sql)
  end

  def get_first_row(sql, params = [])
    params = convert_params(params)
    conn = Thread.current[:dami_sqlite_connection]
    conn ? conn.get_first_row(sql, params) : @connection_pool.with { |c| c.get_first_row(sql, params) }
  rescue SQLite3::Exception => e
    handle_sqlite_error(e, sql: sql)
  end

  def last_insert_row_id
    conn = Thread.current[:dami_sqlite_connection]
    conn ? conn.last_insert_row_id : @connection_pool.with(&:last_insert_row_id)
  end

  private

  # One place that turns Ruby values into what SQLite can bind. Used by every
  # code path that talks to the driver (raw execute, prepared statements, inserts).
  def convert_params(params)
    Array(params).map { |value| convert_value(value) }
  end

  def convert_value(value)
    case value
    when Time then value.utc.strftime('%Y-%m-%d %H:%M:%S')
    when DateTime then value.to_time.utc.strftime('%Y-%m-%d %H:%M:%S')
    when Date then value.to_s
    when TrueClass, FalseClass then value ? 1 : 0
    when Hash, Array then JSON.generate(value)
    else value
    end
  end

  def handle_sqlite_error(error, sql: nil)
    msg = error.message
    if msg.include?('UNIQUE constraint failed')
      column = extract_column_from_unique_error(msg)
      raise Dami::UniqueConstraintViolation.new(msg, column: column)
    elsif msg.include?('FOREIGN KEY constraint failed')
      raise Dami::ForeignKeyViolation.new(msg)
    elsif msg.include?('NOT NULL constraint failed')
      raise Dami::NotNullViolation.new(msg, column: extract_column_from_not_null_error(msg))
    else
      raise error
    end
  end

  def extract_column_from_unique_error(msg)
    match = msg.match(/UNIQUE constraint failed: (\w+)\.(\w+)/)
    match ? match[2].to_sym : nil
  end

  def extract_column_from_not_null_error(msg)
    match = msg.match(/NOT NULL constraint failed: (\w+)\.(\w+)/)
    match ? match[2].to_sym : nil
  end
end
