# File: ./test/migrator_test.rb

# frozen_string_literal: true
require_relative 'test_helper'

class MigratorTest < Minitest::Test
  def setup
    @db_path = "migrator_test.db"
    @migrations_path = "test_migrations"

    FileUtils.rm_rf(@migrations_path)
    self.class.cleanup_database_files(@db_path)

    FileUtils.mkdir_p(@migrations_path)

    @adapter = Dami.connect(:default, adapter: :sqlite, path: @db_path)
    @migrator = Dami::Migrator.new(@adapter, path: @migrations_path)
  end

  def teardown
    if @adapter
      pool = @adapter.instance_variable_get(:@connection_pool)
      pool&.shutdown(&:close)
    end

    self.class.cleanup_database_files(@db_path)

    FileUtils.rm_rf(@migrations_path)
  end

  def create_migration(version, content)
    File.write(File.join(@migrations_path, "#{version}_test.rb"), content)
  end


  def test_migrate_and_rollback
    create_migration("20251015113200", <<~RUBY)
      def run
        create_table(:users) { |t| t.field(:name, :string) }
      end
      def reverse
        drop_table(:users)
      end
    RUBY
  end

  def test_migration_failure_rolls_back_transaction
    create_migration("20251015113201", "create_table(:good_table) { |t| t.field(:name, :string) }")
    create_migration("20251015113202", "add_column(:bad_table, :email, :string)")

    assert_raises(SQLite3::SQLException) { @migrator.migrate }

    assert @adapter.table_exists?(:good_table)
    query = { model_name: :schema_migrations, conditions: [] }
    assert_equal 1, @adapter.query_records(query).count
  end
end