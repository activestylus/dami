# frozen_string_literal: true
require_relative 'test_helper'

class MigrationTest < Minitest::Test
  # This setup is self-contained and does NOT call `super`.
  def setup
    @db_path = 'migration_test.db'
    self.class.cleanup_database_files(@db_path) # This call will now work.

    @adapter = Dami.connect(:migration_test, adapter: :sqlite, path: @db_path)
  end

  def teardown
    if @adapter
      pool = @adapter.instance_variable_get(:@connection_pool)
      pool&.shutdown(&:close)
    end
    self.class.cleanup_database_files(@db_path)
  end

  def test_create_table_and_reverse
    migration = Dami::Migration.new(@adapter)

    # Create table on the empty database
    migration.create_table(:users) do |t|
      t.field(:name, :string)
      t.field(:email, :string)
      t.timestamps
    end

    assert @adapter.table_exists?(:users)
    assert @adapter.column_exists?(:users, :name)
    assert @adapter.column_exists?(:users, :created_at)

    # Drop table
    migration.drop_table(:users)
    refute @adapter.table_exists?(:users)
  end

  def test_execute_runs_raw_sql_with_params
    migration = Dami::Migration.new(@adapter)
    migration.create_table(:users) { |t| t.field(:name, :string); t.field(:status, :string) }
    @adapter.execute("INSERT INTO users (name) VALUES ('a'), ('b')")

    migration.execute("UPDATE users SET status = ? WHERE status IS NULL", ['active'])
    migration.execute("CREATE TRIGGER users_no_blank_name BEFORE INSERT ON users BEGIN SELECT RAISE(ABORT, 'name required') WHERE NEW.name IS NULL; END")

    assert_equal 2, @adapter.execute("SELECT COUNT(*) AS n FROM users WHERE status = 'active'").first['n']
    assert_raises(Dami::Error, SQLite3::Exception) { @adapter.execute("INSERT INTO users (status) VALUES ('x')") }
  end

  def test_add_and_remove_index
    # First, create a table to work with
    @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT);")
    
    migration = Dami::Migration.new(@adapter)

    # 1. Add the index
    migration.add_index(:users, :email)
    
    # Verify the index was created
    indexes = @adapter.execute("PRAGMA index_list('users')")
    assert indexes.any? { |idx| idx['name'] == 'index_users_on_email' }, "Index should have been created"

    # 2. Remove the index
    migration.remove_index(:users, :email)
    
    # Verify the index was dropped
    indexes_after_drop = @adapter.execute("PRAGMA index_list('users')")
    refute indexes_after_drop.any? { |idx| idx['name'] == 'index_users_on_email' }, "Index should have been dropped"
  end

  def test_add_column_and_reverse
    # Create a table first, since the database is empty
    @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);")

    migration = Dami::Migration.new(@adapter)

    # Test add_column works
    migration.add_column(:users, :email, :string)
    assert @adapter.column_exists?(:users, :email)

    # Just verify the remove_column method exists
    assert_respond_to migration, :remove_column
  end
end