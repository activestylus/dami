# test/select_test.rb
require_relative 'test_helper'

class SelectTest < Minitest::Test
   def setup
    super
    Dami.model :users do
      fields { field :name, :string; field :email, :string; field :age, :integer; field :created_at, :datetime }
    end
    Dami.model :posts do
      fields { field :user_id, :integer; field :title, :string; field :content, :text; field :published, :boolean }
    end
    @user1 = @db[:users].create(name: 'Alice', email: 'alice@example.com', age: 30, created_at: Time.now)
    @user2 = @db[:users].create(name: 'Bob', email: 'bob@example.com', age: 25, created_at: Time.now)
    @post1 = @db[:posts].create(user_id: @user1[:id], title: 'First Post', content: 'Hello world', published: true)
    @post2 = @db[:posts].create(user_id: @user2[:id], title: 'Second Post', content: 'Test content', published: false)
  end
def test_left_join_includes_records_without_association
    user_with_post = @user1
    # For clarity, let's create a user who definitely has no posts
    user_without_post = @db[:users].create(name: 'Charlie')

    # THE FIX: The key of the hash should be the column from the original table (`users`),
    # and the value should be the column from the table you're joining (`posts`).
    results = @db[:users]
      .left_join(:posts, { id: :user_id }) # Corrected from { user_id: :id }
      .select('users.name', 'posts.title AS post_title')
      .order('users.name')
      .to_a
      
    # The query should now return all 3 users
    assert_equal 3, results.length
    
    alice_result = results.find { |r| r[:name] == 'Alice' }
    charlie_result = results.find { |r| r[:name] == 'Charlie' }
    
    assert_equal 'First Post', alice_result[:post_title]
    assert_nil charlie_result[:post_title], "User without a post should have a nil post_title"
  end
  def test_basic_select
    users = @db[:users].select(:name, :email).to_a
    
    assert_equal 2, users.length
    users.each do |user|
      assert user[:name]
      assert user[:email]
      # Test that unselected columns return nil when accessed
      assert_nil user[:age]
      assert_nil user[:created_at]
    end
  end
  
def test_select_with_where
  user = @db[:users]
    .select(:name, :age)
    .where(name: 'Alice')
    .first
  
  assert user
  assert_equal 'Alice', user[:name]
  assert_equal 30, user[:age]
  
  hash = user.to_h
  assert hash.key?(:name)
  assert hash.key?(:age) 
  refute hash.key?(:email), "Email should not be present in to_h: #{hash.keys}"
  assert_nil user[:email]
end
  
def test_select_with_ordering
  users = @db[:users]
    .select(:name)
    .order(:id)
    .to_a
  assert_equal ['Alice', 'Bob'], users.map { |u| u[:name] }
  
  # Check that we only have the selected columns in the to_h representation
  users.each do |user|
    hash = user.to_h
    assert hash.key?(:name)
    refute hash.key?(:email), "Email should not be present in to_h: #{hash.keys}"
    refute hash.key?(:age), "Age should not be present in to_h: #{hash.keys}"
    assert_nil user[:email], "Email access should return nil"
  end
end
def test_debug_sql_generation
  # Enable SQL debugging
  
  @db[:users].select(:name, :email).to_a
  @db[:users].select(:name).order(:id).to_a
  @db[:users].select(:name, :age).where(name: 'Alice').to_a
  
end
def test_select_with_limit
  users = @db[:users]
    .select(:name)
    .order(:id)
    .limit(1)
    .to_a
  
  assert_equal 1, users.length
  assert_equal 'Alice', users.first[:name]
  
  hash = users.first.to_h
  assert hash.key?(:name)
  refute hash.key?(:email), "Email should not be present in to_h: #{hash.keys}"
  assert_nil users.first[:email]
end
  
  def test_select_all_columns_explicitly
    users = @db[:users]
      .select(:id, :name, :email, :age, :created_at)
      .to_a
    
    assert_equal 2, users.length
    users.each do |user|
      # All explicitly selected columns should be present
      assert user[:id]
      assert user[:name]
      assert user[:email]
      assert user[:age]
      assert user[:created_at]
    end
  end
  
  def test_select_single_column
    users = @db[:users]
      .select(:name)
      .to_a
    
    assert_equal 2, users.length
    users.each do |user|
      assert user[:name]
      assert_nil user[:email]
      assert_nil user[:age]
    end
  end
  
def test_select_with_join_columns
  # Debug the query structure

  query = @db[:posts]
    .join(:users, { user_id: :id })
    .select('posts.title', 'users.name AS author_name')
  posts_with_users = query.to_a
  assert_equal 2, posts_with_users.length
  posts_with_users.each do |record|
    assert record[:title]
    assert record[:author_name]
    # Other columns should not be present
    assert_nil record[:content]
    assert_nil record[:email]
  end
  
  # Verify the join worked correctly
  alice_post = posts_with_users.find { |p| p[:author_name] == 'Alice' }
  assert alice_post
  assert_equal 'First Post', alice_post[:title]
end
  
  # Skip aggregate functions for now
def test_select_with_aggregate_functions
  # Test COUNT
  result = @db[:users]
    .select('COUNT(*) AS user_count')
    .first
  
  assert result
  assert_equal 2, result[:user_count]
  
  # Test AVG
  result = @db[:users]
    .select('AVG(age) AS average_age')
    .first
  
  assert result
  assert_equal 27.5, result[:average_age] # (30 + 25) / 2
end
  # Skip aliases for now
def test_select_with_aliases
  users = @db[:users]
    .select('name AS user_name', 'email AS user_email')
    .to_a
  
  assert_equal 2, users.length
  users.each do |user|
    assert user[:user_name]
    assert user[:user_email]
    # Original column names should not be present
    assert_nil user[:name]
    assert_nil user[:email]
  end
end
  def test_select_chaining
    # Select can be chained and overridden
    users = @db[:users]
      .select(:name, :email)
      .select(:age)  # Override previous select
      .to_a
    
    users.each do |user|
      assert user[:age]
      # Previous selections should not be present when overridden
      assert_nil user[:name], "Name should be nil when select is overridden"
      assert_nil user[:email], "Email should be nil when select is overridden"
    end
  end
  
  def test_empty_select_returns_all_columns
    users = @db[:users].select().to_a  # Empty select
    
    assert_equal 2, users.length
    users.each do |user|
      # Should behave like SELECT *
      assert user[:id]
      assert user[:name]
      assert user[:email]
      assert user[:age]
      assert user[:created_at]
    end
  end
  
  def test_select_with_scopes
    # Test that select works with scopes
    users = @db[:users]
      .where(age: 30)
      .select(:name)
      .to_a
    
    assert_equal 1, users.length
    assert_equal 'Alice', users.first[:name]
    assert_nil users.first[:email]
  end
  
  def test_select_to_h_returns_filtered_columns
    # Test that to_h also respects select
    user = @db[:users]
      .select(:name, :email)
      .first
      .to_h
    
    assert user[:name]
    assert user[:email]
    refute user.key?(:age), "Age should not be in to_h result"
    refute user.key?(:created_at), "Created at should not be in to_h result"
  end
end