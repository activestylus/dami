# frozen_string_literal: true
require_relative 'test_helper'
class DraftTest < Minitest::Test
  def setup
    super
  end
  def test_update_with_successful_draft
    user = @db[:users].create(name: 'jane doe', email: 'jane@test.com', status: 'active')
    @db[:users].where(id: user[:id]).update(name: '  JANE DOE  ') do |d|
      d.transform(:normalize_name) { |data| data[:name] = data[:name].strip.capitalize; data }
    end
    refreshed = @db[:users].find(user[:id])
    assert_equal 'Jane doe', refreshed[:name]
  end
  def test_update_with_failing_draft
    user = @db[:users].create(name: 'Jane', email: 'jane@test.com', status: 'active')
    result = @db[:users].where(id: user[:id]).update(email: 'new@email.com') do |d|
      d.prevent_changes :email, message: "Email is protected"
    end
    assert_nil result
    refreshed = @db[:users].find(user[:id])
    assert_equal 'jane@test.com', refreshed[:email]
  end
  def test_create_with_draft_block
    new_user_attrs = { name: '  john smith  ', email: 'john@test.com', status: 'active' }
    user = @db[:users].create(new_user_attrs) do |d|
      d.transform(:normalize) { |data| data[:name] = data[:name].strip.split.map(&:capitalize).join(' '); data }
      d.verify(:name_length, error: "Name is too short") { d.get(:name).length > 3 }
    end
    assert_equal 'John Smith', user[:name]
  end
  def test_create_with_failing_draft_raises_error
    assert_raises(Dami::ValidationError) do
      @db[:users].create(name: 'Jo', status: 'active') do |d|
        d.verify(:name_length, error: "Name is too short") { d.get(:name).length > 3 }
      end
    end
    assert_equal 0, @db[:users].where({}).count
  end
end