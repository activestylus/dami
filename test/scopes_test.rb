# File: test/scopes_test.rb

require_relative 'test_helper'

class ScopesTest < Minitest::Test
  def setup
    super
    # Self-contained model definitions
    Dami.model(:users) do
      fields do
        field :first_name, :string
        field :last_name, :string
        field :status, :string
        field :role, :string
        field :created_at, :datetime
      end
    end
    
    Dami.model(:posts) do
      fields do
        field :user_id, :integer
        field :title, :string
        field :status, :string
        field :published_at, :datetime
      end
    end
    
    Dami.scopes(:users) do
      scope :active, -> { where(status: 'active') }
      scope :admins, -> { where(role: 'admin') }
      scope :by_status, ->(status) { where(status: status) }
      scope :recent, -> { where('created_at > ?', Time.now - 86400) }
    end
    
    Dami.scopes(:posts) do
      scope :published, -> { where(status: 'published') }
      scope :drafts, -> { where(status: 'draft') }
    end

    now = Time.now
    @user1 = @db[:users].create(first_name: 'Alice', last_name: 'A', status: 'active', role: 'user', created_at: now, permit: [:role])
    @user2 = @db[:users].create(first_name: 'Bob', last_name: 'B', status: 'inactive', role: 'user', created_at: now - 172800, permit: [:role])
    @user3 = @db[:users].create(first_name: 'Admin', last_name: 'User', status: 'active', role: 'admin', created_at: now, permit: [:role])
    @post1 = @db[:posts].create(user_id: @user1[:id], title: 'Published Post', status: 'published', published_at: now)
    @post2 = @db[:posts].create(user_id: @user1[:id], title: 'Draft Post', status: 'draft', published_at: now)
  end
  
  def test_scope_methods_exist
    assert_respond_to @db[:users], :active
    assert_respond_to @db[:posts], :published
  end
  
  def test_basic_scope_usage
    active_users = @db[:users].active.to_a
    assert_equal 2, active_users.length
    
    active_user_names = active_users.map { |u| u[:first_name] }
    assert_includes active_user_names, 'Alice'
    assert_includes active_user_names, 'Admin'
    
    admins = @db[:users].admins.to_a
    assert_equal 1, admins.length
    assert_equal 'Admin', admins.first[:first_name]
  end

  def test_scope_with_arguments
    inactive_users = @db[:users].by_status('inactive').to_a
    assert_equal 1, inactive_users.length
    assert_equal 'Bob', inactive_users.first[:first_name]
  end

  def test_scope_chaining
    recent_active_users = @db[:users].active.recent.to_a
    assert_equal 2, recent_active_users.length
    
    recent_admins = @db[:users].admins.recent.to_a
    assert_equal 1, recent_admins.length
    assert_equal 'Admin', recent_admins.first[:first_name]
  end
  
  def test_cross_model_scopes
    published_posts = @db[:posts].published.to_a
    assert_equal 1, published_posts.length
    assert_equal 'Published Post', published_posts.first[:title]
    
    draft_posts = @db[:posts].drafts.to_a
    assert_equal 1, draft_posts.length
    assert_equal 'Draft Post', draft_posts.first[:title]
  end
  
  def test_scope_with_other_query_methods
    recent_active_alice = @db[:users]
      .active
      .recent
      .where(first_name: 'Alice')
      .to_a
      
    assert_equal 1, recent_active_alice.length
    assert_equal 'Alice', recent_active_alice.first[:first_name]
  end
  
  def test_scopes_with_ordering
    users = @db[:users].active.order(:id).to_a
    assert_equal ['Alice', 'Admin'], users.map { |u| u[:first_name] }
  end
  
  def test_scopes_with_limit
    users = @db[:users].active.order(:id).limit(1).to_a
    assert_equal 1, users.length
    assert_equal 'Alice', users.first[:first_name]
  end
  
  def test_scopes_with_offset
    users = @db[:users].active.order(:id).limit(1).offset(1).to_a
    assert_equal 1, users.length
    assert_equal 'Admin', users.first[:first_name]
  end
  
  def test_scopes_with_where_chaining
    admin_alice = @db[:users]
      .active
      .where(first_name: 'Alice')
      .to_a
    
    assert_equal 1, admin_alice.length
    assert_equal 'Alice', admin_alice.first[:first_name]
  end
  
  def test_complex_scope_chain
    result = @db[:users]
      .active
      .where(role: 'user')
      .order(:id)
      .limit(5)
      .to_a
    
    assert_equal 1, result.length
    assert_equal 'Alice', result.first[:first_name]
  end
  
  def test_undefined_methods_still_raise_errors
    assert_raises(NoMethodError) do
      @db[:users].nonexistent_method
    end
  end
end