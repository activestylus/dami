# frozen_string_literal: true
require_relative 'test_helper'

class CoreTest < Minitest::Test
  def setup
    super
    # A simplified local model.
    Dami.model :users do
      fields do
        field :first_name, :string
        field :last_name, :string
        field :email, :string
        field :age, :integer
        field :status, :string
        field :role, :string
      end
    end
  end

  def test_crud_cycle
    created = @db[:users].create(first_name: 'Alice', last_name: 'A', email: 'alice@example.com')
    assert_instance_of Dami::RecordProxy, created
    assert_equal 'Alice', created[:first_name]
    assert created[:id]

    found = @db[:users].find(created[:id])
    assert_instance_of Dami::RecordProxy, found
    assert_equal created[:id], found[:id]
    assert_equal 'Alice', found[:first_name]

    queried = @db[:users].where(email: 'alice@example.com').to_a
    assert_equal 1, queried.length
    assert_equal 'Alice', queried.first[:first_name]

    @db[:users].where(id: created[:id]).update(first_name: 'Alicia')
    updated = @db[:users].find(created[:id])
    assert_equal 'Alicia', updated[:first_name]

    @db[:users].where(id: created[:id]).delete
    assert_nil @db[:users].find(created[:id])
  end

  def test_find_returns_nil_for_non_existent_id
    assert_nil @db[:users].find(9999)
  end

  def test_where_returns_empty_array_for_no_matches
    @db[:users].create(first_name: 'Alice', email: 'alice@example.com')
    results = @db[:users].where(first_name: 'Bob').to_a
    assert_equal [], results
  end

  def test_chained_where_clauses_act_as_and
    @db[:users].create(first_name: 'Alice', email: 'alice@one.com')
    @db[:users].create(first_name: 'Alice', email: 'alice@two.com')
    results = @db[:users].where(first_name: 'Alice').where(email: 'alice@two.com').to_a
    assert_equal 1, results.length
    assert_equal 'alice@two.com', results.first[:email]
  end

  def test_update_on_non_matching_query_does_nothing
    user = @db[:users].create(first_name: 'Alice', email: 'alice@example.com')
    @db[:users].where(first_name: 'Bob').update(email: 'hacked@example.com')
    refreshed_user = @db[:users].find(user[:id])
    assert_equal 'alice@example.com', refreshed_user[:email]
  end

  def test_delete_on_non_matching_query_does_nothing
    @db[:users].create(first_name: 'Alice', email: 'alice@example.com')
    @db[:users].where(first_name: 'Bob').delete
    assert_equal 1, @db[:users].where({}).all.count
  end

  def test_record_proxy_to_h_returns_a_plain_hash
    created = @db[:users].create(first_name: 'Alice', email: 'alice@example.com')
    record_hash = created.to_h
    assert_instance_of Hash, record_hash
    refute_instance_of Dami::RecordProxy, record_hash
    assert_equal 'Alice', record_hash[:first_name]
  end

  def test_where_with_nil_value_generates_is_null
    @db[:users].create(first_name: 'Alice', email: 'alice@example.com')
    @db[:users].create(first_name: 'Bob', email: nil)
    results = @db[:users].where(email: nil).to_a
    assert_equal 1, results.length
    assert_equal 'Bob', results.first[:first_name]
  end

  def test_where_with_empty_array_for_in_clause_returns_nothing
    @db[:users].create(first_name: 'Alice', email: 'alice@example.com')
    results = @db[:users].where(id: []).to_a
    assert_equal [], results
  end

  def test_order_with_direction
    user_c = @db[:users].create(first_name: 'Charlie')
    user_a = @db[:users].create(first_name: 'Alice')
    results_asc = @db[:users].order(first_name: :asc).to_a
    results_desc = @db[:users].order(first_name: :desc).to_a
    assert_equal [user_a[:id], user_c[:id]], results_asc.map { |r| r[:id] }
    assert_equal [user_c[:id], user_a[:id]], results_desc.map { |r| r[:id] }
  end

  def test_limit_and_offset
    (1..10).each { |i| @db[:users].create(first_name: "User-#{i}") }
    results = @db[:users].order(:id).limit(3).offset(4).to_a
    assert_equal 3, results.length
    assert_equal 'User-5', results.first[:first_name]
    assert_equal 'User-7', results.last[:first_name]
  end

  def test_where_with_multiple_operators_in_hash
    @db[:users].create(first_name: 'Alice', age: 25)
    @db[:users].create(first_name: 'Bob', age: 35)
    @db[:users].create(first_name: 'Charlie', age: 45)
    results = @db[:users].where(age: { gt: 30, lt: 40 }).to_a
    assert_equal 1, results.length
    assert_equal 'Bob', results.first[:first_name]
  end

  def test_query_builder_immutability
    query1 = @db[:users].where(first_name: 'Alice')
    query2 = query1.limit(5)
    refute_same query1, query2
    assert_nil query1.instance_variable_get(:@limit)
    assert_equal 5, query2.instance_variable_get(:@limit)
  end

  def test_first_and_last_on_query
    user1 = @db[:users].create(first_name: 'First')
    @db[:users].create(first_name: 'Middle')
    user3 = @db[:users].create(first_name: 'Last')

    query = @db[:users].order(:id)
    assert_equal user1[:id], query.first[:id]
    assert_equal user3[:id], query.last[:id]
  end

  def test_query_is_enumerable
    @db[:users].create(first_name: 'Alice')
    @db[:users].create(first_name: 'Bob')

    query = @db[:users].where(first_name: ['Alice', 'Bob'])
    assert_equal true, query.any?
    assert_equal ['Alice', 'Bob'], query.map { |u| u[:first_name] }.sort
  end

  def test_update_multiple_records
    @db[:users].create(first_name: 'User', email: 'old@a.com')
    @db[:users].create(first_name: 'User', email: 'old@b.com')
    @db[:users].create(first_name: 'Other', email: 'old@c.com')

    @db[:users].where(first_name: 'User').update(email: 'new@example.com')

    assert_equal 2, @db[:users].where(email: 'new@example.com').count
    assert_equal 1, @db[:users].where(email: 'old@c.com').count
  end

  def test_delete_multiple_records
    @db[:users].create(first_name: 'ToDelete')
    @db[:users].create(first_name: 'ToDelete')
    @db[:users].create(first_name: 'ToKeep')

    @db[:users].where(first_name: 'ToDelete').delete
    assert_equal 1, @db[:users].count
    assert_equal 'ToKeep', @db[:users].first[:first_name]
  end

  def test_where_with_array_for_in_clause
    user1 = @db[:users].create(first_name: 'Alice')
    @db[:users].create(first_name: 'Bob')
    user3 = @db[:users].create(first_name: 'Charlie')

    results = @db[:users].where(id: [user1[:id], user3[:id]]).to_a
    assert_equal 2, results.length
    assert_equal ['Alice', 'Charlie'], results.map { |u| u[:first_name] }.sort
  end

  def test_where_with_not_and_range_operators
    @db[:users].create(first_name: 'Alice', age: 20)
    @db[:users].create(first_name: 'Bob', age: 30)
    @db[:users].create(first_name: 'Charlie', age: 40)
    @db[:users].create(first_name: 'David', age: 50)

    results_not = @db[:users].where(age: { not: 30 }).to_a
    assert_equal 3, results_not.length
    refute_includes results_not.map { |u| u[:first_name] }, 'Bob'

    results_gte = @db[:users].where(age: { gte: 40 }).to_a
    assert_equal 2, results_gte.length
    assert_equal ['Charlie', 'David'], results_gte.map { |u| u[:first_name] }.sort
  end

  def test_existence_checks
    @db[:users].create(first_name: 'Alice', age: 25)
    assert @db[:users].any?
    assert @db[:users].exists?
    assert @db[:users].exists?(first_name: 'Alice')
    assert @db[:users].where(age: 25).any?
    refute @db[:users].where(first_name: 'Bob').any?
    refute @db[:users].exists?(first_name: 'Bob')
    @db[:users].delete
    refute @db[:users].any?
  end

  def test_where_with_advanced_operators
    @db[:users].create(first_name: 'Alice', age: 25)
    @db[:users].create(first_name: 'Alicia', age: 30)
    @db[:users].create(first_name: 'Bob', age: 35)

    starts_with_results = @db[:users].where(first_name: { starts_with: 'Ali' }).to_a
    assert_equal 2, starts_with_results.length
    assert_equal ['Alice', 'Alicia'], starts_with_results.map { |u| u[:first_name] }.sort

    contains_results = @db[:users].where(first_name: { contains: 'lic' }).to_a
    assert_equal 2, contains_results.length

    ends_with_results = @db[:users].where(first_name: { ends_with: 'ce' }).to_a
    assert_equal 1, ends_with_results.length
    assert_equal 'Alice', ends_with_results.first[:first_name]
    
    not_in_results = @db[:users].where(first_name: { not_in: ['Alicia', 'Bob'] }).to_a
    assert_equal 1, not_in_results.length
    assert_equal 'Alice', not_in_results.first[:first_name]
  end

  def test_or_condition_connects_queries
    @db[:users].create(first_name: 'Alice', age: 25)
    @db[:users].create(first_name: 'Bob', age: 35)
    @db[:users].create(first_name: 'Charlie', age: 25)

    results = @db[:users].where(first_name: 'Bob').or(age: 25).to_a
    assert_equal 3, results.length
    assert_equal ['Alice', 'Bob', 'Charlie'], results.map { |u| u[:first_name] }.sort
  end

  def test_ordering_by_multiple_fields
    @db[:users].create(first_name: 'Bob', age: 30)
    @db[:users].create(first_name: 'Alice', age: 30)
    @db[:users].create(first_name: 'Charlie', age: 20)

    results = @db[:users].order(age: :asc, first_name: :desc).to_a
    assert_equal ['Charlie', 'Bob', 'Alice'], results.map { |u| u[:first_name] }
  end

  def test_count_method_on_query
    (1..7).each { |i| @db[:users].create(first_name: "User #{i}") }
    assert_equal 7, @db[:users].count
    assert_equal 3, @db[:users].where(id: { gt: 4 }).count
  end

  # ===== RESTORED TESTS FROM OLD VERSION =====

  def test_where_with_not_in_empty_array_returns_all
    user1 = @db[:users].create(first_name: 'Alice')
    user2 = @db[:users].create(first_name: 'Bob')

    # This should be interpreted as "WHERE id NOT IN ()", which is always true.
    results = @db[:users].where(id: { not_in: [] }).to_a
    assert_equal 2, results.length, "A 'not_in' with an empty array should return all records"
  end

  def test_where_with_boolean_values
    # Need to create posts model for this test
    Dami.model :posts do
      fields do
        field :user_id, :integer
        field :title, :string
        field :published, :boolean
      end
    end

    published_post = @db[:posts].create(title: 'Published Post', published: true, user_id: 1)
    draft_post = @db[:posts].create(title: 'Draft Post', published: false, user_id: 1)

    results = @db[:posts].where(published: true).to_a
    assert_equal 1, results.length
    assert_equal published_post[:id], results.first[:id]
  end

  def test_where_with_not_nil_generates_is_not_null
    @db[:users].create(first_name: 'Alice', email: 'alice@example.com')
    @db[:users].create(first_name: 'Bob', email: nil)
    
    results = @db[:users].where(email: { not: nil }).to_a
    assert_equal 1, results.length
    assert_equal 'Alice', results.first[:first_name]
  end

  def test_where_with_nested_or_conditions
    @db[:users].create(first_name: 'Alice', age: 25, status: 'active')
    @db[:users].create(first_name: 'Bob', age: 30, status: 'active')
    @db[:users].create(first_name: 'Bob', age: 35, status: 'pending')
    @db[:users].create(first_name: 'Charlie', age: 30, status: 'pending')

    results = @db[:users].where(first_name: 'Bob').where do |q|
      q.where(age: 30).or(status: 'pending')
    end.to_a

    assert_equal 2, results.length
    assert_equal ['Bob', 'Bob'], results.map { |u| u[:first_name] }
  end
end