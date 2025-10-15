# frozen_string_literal: true
require_relative 'test_helper'
class AssociationsTest < Minitest::Test
def setup
    super # This is CRITICAL. It runs the main helper setup first.

    # THE FIX: Override the global models with simpler, validation-free versions
    # that are specific to the needs of this test file.
    Dami.model :users do
      fields { field :name, :string }
      relationships do
        has_one :profile
        has_many :posts
      end
    end

    Dami.model :profiles do
      fields { field :user_id, :integer; field :bio, :text }
      relationships { belongs_to :user }
    end

    Dami.model :posts do
      fields { field :user_id, :integer; field :title, :string }
      relationships { belongs_to :user }
    end

    # Now, this data creation will succeed because the local models have no validation rules.
    @user1 = @db[:users].create(name: 'Alice')
    @user2 = @db[:users].create(name: 'Bob')
    @profile1 = @db[:profiles].create(user_id: @user1[:id], bio: 'Alice Bio')
    @post1 = @db[:posts].create(user_id: @user1[:id], title: 'Post 1')
    @post2 = @db[:posts].create(user_id: @user1[:id], title: 'Post 2')
  end

  def test_lazy_load_belongs_to
    post = @db[:posts].find(@post1[:id])
    assert_equal 'Alice', post.user[:name]
  end
  def test_lazy_load_has_one
    user = @db[:users].find(@user1[:id])
    assert_equal 'Alice Bio', user.profile[:bio]
  end
  def test_lazy_load_has_many
    user = @db[:users].find(@user1[:id])
    assert_equal 2, user.posts.length
    assert_equal ['Post 1', 'Post 2'], user.posts.map { |p| p[:title] }.sort
  end
  def test_preload_belongs_to
    posts = @db[:posts].preload(:user).to_a
    assert_equal 'Alice', posts.find { |p| p[:id] == @post1[:id] }.user[:name]
  end
  def test_preload_has_one
    users = @db[:users].preload(:profile).to_a
    assert_equal 'Alice Bio', users.find { |u| u[:id] == @user1[:id] }.profile[:bio]
  end
  def test_preload_has_many
    users = @db[:users].preload(:posts).to_a
    alice = users.find { |u| u[:id] == @user1[:id] }
    bob = users.find { |u| u[:id] == @user2[:id] }
    assert_equal 2, alice.posts.length
    assert_equal 0, bob.posts.length
  end
  def test_preload_multiple_associations
    users = @db[:users].preload(:profile, :posts).to_a
    alice = users.find { |u| u[:id] == @user1[:id] }
    assert alice.posts.is_a?(Array)
    assert alice.profile.is_a?(Dami::RecordProxy)
    assert_equal 2, alice.posts.length
    assert_equal 'Alice Bio', alice.profile[:bio]
  end
end