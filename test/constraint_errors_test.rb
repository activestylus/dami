# File: test/constraint_errors_test.rb
require_relative 'test_helper'
class ConstraintErrorsTest < Minitest::Test
# File: test/constraint_errors_test.rb
def setup
  super
  @db.execute("PRAGMA foreign_keys = ON")
  @db.execute("CREATE UNIQUE INDEX unique_email ON users(email)")
end
def test_foreign_key_raises_custom_error
  @db.execute("PRAGMA foreign_keys = ON")
  @db.execute("CREATE TABLE IF NOT EXISTS test_posts (id INTEGER PRIMARY KEY, user_id INTEGER, title TEXT, FOREIGN KEY(user_id) REFERENCES users(id))")
  error = assert_raises(Dami::ForeignKeyViolation) do
    @db.execute("INSERT INTO test_posts (user_id, title) VALUES (99999, 'Orphan')")
  end
  assert_includes error.message, "FOREIGN KEY constraint failed"
end
def teardown
  @db.execute("DROP TABLE IF EXISTS test_posts")
  @db.execute("DROP INDEX IF EXISTS unique_email")
  super
end
end