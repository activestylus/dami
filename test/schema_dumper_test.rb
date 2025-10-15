# File: ./test/schema_dumper_test.rb

require_relative 'test_helper'
require_relative '../lib/dami/schema/dumper'

class SchemaDumperTest < Minitest::Test
  def setup
    super
    # This test needs a clean slate, so we wipe any tables created by the main helper
    DatabaseHelper.drop_all_tables(@db)
  end
  
  # The dumper relies on DDL, which can't run inside a transaction.
  # We override `around` to disable transactions for this test class.
  def around
    yield
  end

  def test_dump_generates_correct_schema_string
    # 1. Create a specific schema to test against.
    pk = DatabaseHelper.pk_type
    @db.execute("CREATE TABLE users (id #{pk}, name TEXT, email TEXT);")
    @db.execute("CREATE TABLE posts (id #{pk}, user_id INTEGER, title TEXT);")
    @db.execute("CREATE INDEX index_posts_on_user_id ON posts (user_id);")

    # 2. Run the dumper.
    dumper = Dami::Schema::Dumper.new(@db)
    schema_output = dumper.dump

    # 3. Assert that the output contains the expected definitions.
    assert_includes schema_output, 'create_table "users"'
    assert_includes schema_output, 't.field "name", :string'
    assert_includes schema_output, 't.field "email", :string'
    
    assert_includes schema_output, 'create_table "posts"'
    assert_includes schema_output, 't.field "user_id", :integer'

    assert_includes schema_output, 'add_index "posts", "user_id"'
  end
end