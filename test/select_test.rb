# test/select_test.rb

require_relative 'test_helper'

class SelectTest < Minitest::Test
  def setup
    super
    # Use the new schema for local models and data creation
    Dami.model :users do
      fields { field :first_name, :string; field :last_name, :string; field :email, :string; field :age, :integer; field :created_at, :datetime }
    end
    Dami.model :posts do
      fields { field :user_id, :integer; field :title, :string; field :content, :text; field :published, :boolean }
    end
    @user1 = @db[:users].create(first_name: 'Alice', last_name: 'A', email: 'alice@example.com', age: 30, created_at: Time.now)
    @user2 = @db[:users].create(first_name: 'Bob', last_name: 'B', email: 'bob@example.com', age: 25, created_at: Time.now)
    @post1 = @db[:posts].create(user_id: @user1[:id], title: 'First Post', content: 'Hello world', published: true)
  end

  def test_basic_select
    users = @db[:users].select(:first_name, :email).to_a
    assert_equal 2, users.length
    users.each do |user|
      assert user[:first_name]
      assert user[:email]
      assert_nil user[:age]
    end
  end

  def test_select_with_where
    user = @db[:users].select(:first_name, :age).where(first_name: 'Alice').first
    assert user
    assert_equal 'Alice', user[:first_name]
    assert_equal 30, user[:age]
    
    hash = user.to_h
    assert hash.key?(:first_name)
    assert hash.key?(:age)
    refute hash.key?(:email), "Email should not be present in to_h: #{hash.keys}"
    assert_nil user[:email]
  end

  def test_select_with_ordering
    users = @db[:users].select(:first_name).order(:id).to_a
    assert_equal ['Alice', 'Bob'], users.map { |u| u[:first_name] }
    
    users.each do |user|
      hash = user.to_h
      assert hash.key?(:first_name)
      refute hash.key?(:email), "Email should not be present in to_h: #{hash.keys}"
      refute hash.key?(:age), "Age should not be present in to_h: #{hash.keys}"
      assert_nil user[:email], "Email access should return nil"
    end
  end

  def test_select_with_aliases
    users = @db[:users].select('first_name AS user_name', 'email AS user_email').to_a
    assert_equal 2, users.length
    users.each do |user|
      assert user[:user_name]
      assert user[:user_email]
      # Original column names should not be present
      assert_nil user[:first_name]
      assert_nil user[:email]
    end
  end
  
  def test_select_all_columns_explicitly
    user = @db[:users].select(:id, :first_name, :last_name, :email, :age, :created_at).first
    assert user[:id]
    assert user[:first_name]
    assert user[:created_at]
  end
  
  def test_empty_select_returns_all_columns
    user = @db[:users].select.first
    assert user, "Query should have returned a user"
    assert user[:id]
    assert user[:first_name]
  end

  # ===== RESTORED TESTS FROM OLD VERSION =====

  def test_left_join_includes_records_without_association
    user_with_post = @user1
    user_without_post = @db[:users].create(first_name: 'Charlie', last_name: 'C')

    results = @db[:users]
      .left_join(:posts, { id: :user_id })
      .select('users.first_name', 'posts.title AS post_title')
      .order('users.first_name')
      .to_a
      
    assert_equal 3, results.length
    
    alice_result = results.find { |r| r[:first_name] == 'Alice' }
    charlie_result = results.find { |r| r[:first_name] == 'Charlie' }
    
    assert_equal 'First Post', alice_result[:post_title]
    assert_nil charlie_result[:post_title], "User without a post should have a nil post_title"
  end

  def test_debug_sql_generation
    # This test just ensures queries run without error
    @db[:users].select(:first_name, :email).to_a
    @db[:users].select(:first_name).order(:id).to_a
    @db[:users].select(:first_name, :age).where(first_name: 'Alice').to_a
  end

  def test_select_with_limit
    users = @db[:users]
      .select(:first_name)
      .order(:id)
      .limit(1)
      .to_a
    
    assert_equal 1, users.length
    assert_equal 'Alice', users.first[:first_name]
    
    hash = users.first.to_h
    assert hash.key?(:first_name)
    refute hash.key?(:email), "Email should not be present in to_h: #{hash.keys}"
    assert_nil users.first[:email]
  end

  def test_select_single_column
    users = @db[:users].select(:first_name).to_a
    assert_equal 2, users.length
    users.each do |user|
      assert user[:first_name]
      assert_nil user[:email]
      assert_nil user[:age]
    end
  end

  def test_select_with_join_columns
    query = @db[:posts]
      .join(:users, { user_id: :id })
      .select('posts.title', 'users.first_name AS author_name')
    
    posts_with_users = query.to_a
    assert_equal 1, posts_with_users.length
    
    posts_with_users.each do |record|
      assert record[:title]
      assert record[:author_name]
      assert_nil record[:content]
      assert_nil record[:email]
    end
    
    alice_post = posts_with_users.find { |p| p[:author_name] == 'Alice' }
    assert alice_post
    assert_equal 'First Post', alice_post[:title]
  end

  def test_select_with_aggregate_functions
    # Test COUNT
    result = @db[:users].select('COUNT(*) AS user_count').first
    assert result
    assert_equal 2, result[:user_count]
    
    # Test AVG
    result = @db[:users].select('AVG(age) AS average_age').first
    assert result
    assert_equal 27.5, result[:average_age] # (30 + 25) / 2
  end

  def test_select_chaining
    users = @db[:users]
      .select(:first_name, :email)
      .select(:age)  # Override previous select
      .to_a
    
    users.each do |user|
      assert user[:age]
      assert_nil user[:first_name], "Name should be nil when select is overridden"
      assert_nil user[:email], "Email should be nil when select is overridden"
    end
  end

  def test_select_with_scopes
    users = @db[:users]
      .where(age: 30)
      .select(:first_name)
      .to_a
    
    assert_equal 1, users.length
    assert_equal 'Alice', users.first[:first_name]
    assert_nil users.first[:email]
  end

  def test_select_to_h_returns_filtered_columns
    user = @db[:users]
      .select(:first_name, :email)
      .first
      .to_h
    
    assert user[:first_name]
    assert user[:email]
    refute user.key?(:age), "Age should not be in to_h result"
    refute user.key?(:created_at), "Created at should not be in to_h result"
  end
end