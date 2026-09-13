# File: test/draft_test.rb

require_relative 'test_helper'

class DraftTest < Minitest::Test
  def setup
    super
  end

  def test_update_with_successful_draft
    user = @db[:users].create(first_name: 'jane', last_name: 'doe', email: 'jane@test.com', status: 'active')
    @db[:users].where(id: user[:id]).update(first_name: '  JANE  ') do |d|
      d.transform(:normalize_name) { |data| data[:first_name] = data[:first_name].strip.capitalize; data }
    end
    refreshed = @db[:users].find(user[:id])
    assert_equal 'Jane', refreshed[:first_name]
  end

  def test_update_with_failing_draft
    user = @db[:users].create(first_name: 'Jane', last_name: 'D', email: 'jane@test.com', status: 'active')
    result = @db[:users].where(id: user[:id]).update(email: 'new@email.com') do |d|
      d.prevent_changes :email, message: "Email is protected"
    end
    assert_nil result
    refreshed = @db[:users].find(user[:id])
    assert_equal 'jane@test.com', refreshed[:email]
  end

  def test_create_with_draft_block
    new_user_attrs = { first_name: '  john', last_name: 'smith  ', email: 'john@test.com', status: 'active' }
    user = @db[:users].create(new_user_attrs) do |d|
      d.transform(:normalize) { |data| data[:first_name] = data[:first_name].strip.capitalize; data }
      d.verify(:name_length, error: "Name is too short") { d.get(:first_name).length > 3 }
    end
    assert_equal 'John', user[:first_name]
  end

  def test_draft_can_query_the_database
    @db[:users].create(first_name: 'Taken', last_name: 'D', email: 'taken@test.com', status: 'active')
    result = @db[:users].create(first_name: 'Taken', last_name: 'E', email: 'other@test.com', status: 'active') do |d|
      d.verify(:name_is_unique, error: "This name is already taken") { db(:users).where(first_name: d.get(:first_name)).none? }
    end rescue result = $!
    assert_kind_of Dami::ValidationError, result
    assert_equal({ name_is_unique: ["This name is already taken"] }, result.errors)
    assert_equal 1, @db[:users].where(first_name: 'Taken').count
  end

  def test_create_with_failing_draft_raises_error
    assert_raises(Dami::ValidationError) do
      # Fails because first_name is required by the global validation
      @db[:users].create(first_name: 'Jo', status: 'active') do |d|
        d.verify(:name_length, error: "Name is too short") { d.get(:first_name).length > 3 }
      end
    end
    # The inner validation also fails, so this is correct behavior.
    assert_equal 0, @db[:users].where({}).count
  end
end