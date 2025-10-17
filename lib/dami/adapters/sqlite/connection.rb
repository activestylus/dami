# In lib/dami/adapters/sqlite/connection.rb

# frozen_string_literal: true
require 'connection_pool'

module SqliteConnection
  def connect
    @connection_pool ||= ConnectionPool.new(size: 5, timeout: 5) do
      SQLite3::Database.new(@config[:path]).tap do |db|
        db.results_as_hash = true
        db.busy_timeout = 5000
        db.execute("PRAGMA journal_mode = WAL;")
        db.execute("PRAGMA synchronous = NORMAL;")
        db.instance_variable_set(:@statement_cache, {})
      end
    end
    self
  end

  def transaction(&block)
    @connection_pool.with do |conn|
      if conn.transaction_active?
        # We are already inside a transaction, so just run the code.
        yield
      else
        # This is the top-level call, so we start and manage the transaction.
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
  end

  def execute(sql, params = [])
    conn = Thread.current[:dami_sqlite_connection]
    conn ? conn.execute(sql, params) : @connection_pool.with { |c| c.execute(sql, params) }
  end

  def get_first_row(sql, params = [])
    conn = Thread.current[:dami_sqlite_connection]
    conn ? conn.get_first_row(sql, params) : @connection_pool.with { |c| c.get_first_row(sql, params) }
  end

  def last_insert_row_id
    conn = Thread.current[:dami_sqlite_connection]
    conn ? conn.last_insert_row_id : @connection_pool.with(&:last_insert_row_id)
  end
end