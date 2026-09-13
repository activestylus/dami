# frozen_string_literal: true
# Binary (ASCII-8BIT) strings, which is what Rack hands a web app: text must
# be stored as TEXT and match in a where clause; real binary data stays a BLOB.
require_relative 'test_helper'

class EncodingTest < Minitest::Test
  def test_binary_string_that_is_text_is_stored_as_text
    name = 'Mónica'.b
    user = @db[:users].create(first_name: name, last_name: 'X', email: 'm@test.com', status: 'active')

    assert_equal 'Mónica', user[:first_name]
    assert_equal Encoding::UTF_8, user[:first_name].encoding
    assert_equal 'text', @db.get_first_row("SELECT typeof(first_name) AS t FROM users WHERE id = ?", [user[:id]])['t']
  end

  def test_binary_string_matches_in_where
    @db[:users].create(first_name: 'Flow', last_name: 'X', email: 'f@test.com', status: 'active')

    assert_equal 1, @db[:users].where(first_name: 'Flow'.b).count
    assert_equal 1, @db[:users].where(email: 'f@test.com'.b).count
  end

  def test_binary_string_in_raw_execute_matches
    @db.execute("INSERT INTO tags (name) VALUES (?)", ['ruby'.b])

    assert_equal 1, @db.execute("SELECT COUNT(*) AS n FROM tags WHERE name = ?", ['ruby']).first['n']
    assert_equal 1, @db.execute("SELECT COUNT(*) AS n FROM tags WHERE name = ?", ['ruby'.b]).first['n']
  end

  def test_bytes_that_are_not_utf8_stay_a_blob
    jpeg_header = "\xFF\xD8\xFF\xE0".b
    @db.execute("INSERT INTO tags (name) VALUES (?)", [jpeg_header])

    row = @db.get_first_row("SELECT name, typeof(name) AS t FROM tags")
    assert_equal 'blob', row['t']
    assert_equal jpeg_header, row['name']
  end
end
