require_relative 'test_helper'
require_relative '../lib/dami/schema/diff'

class SchemaDiffTest < Minitest::Test
  def test_diff_detects_added_column
    old_schema = { "users" => { columns: { "name" => {type: :string}}, indexes: {} } }
    new_schema = { "users" => { columns: { "name" => {type: :string}, "email" => {type: :string}}, indexes: {} } }

    differ = Dami::Schema::Diff.new(old_schema, new_schema)
    result = differ.diff

    assert_equal 1, result[:up].length
    assert_equal :add_column, result[:up].first[:command]
    assert_equal "email", result[:up].first[:name]

    assert_equal 1, result[:down].length
    assert_equal :remove_column, result[:down].first[:command]
  end

  def test_diff_detects_added_table_and_index
    old_schema = {}
    new_schema = { "posts" => { columns: { "user_id" => {type: :integer}}, indexes: {"user_id" => {}} } }

    differ = Dami::Schema::Diff.new(old_schema, new_schema)
    result = differ.diff

    assert_equal 2, result[:up].length
    assert_equal :create_table, result[:up][0][:command]
    assert_equal :add_index, result[:up][1][:command]
    
    assert_equal 1, result[:down].length
    assert_equal :drop_table, result[:down][0][:command]
  end
end