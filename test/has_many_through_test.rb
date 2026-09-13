# File: test/has_many_through_test.rb

require_relative 'test_helper'

class HasManyThroughTest < Minitest::Test
  def setup
    super
    
    # All models defined locally so the test is self-contained.
    Dami.model :posts do
      fields { field :title, :string }
      relationships { has_many :posts_tags; has_many :tags, through: :posts_tags }
    end
    Dami.model :tags do
      fields { field :name, :string }
      relationships { has_many :posts_tags; has_many :posts, through: :posts_tags }
    end
    Dami.model :posts_tags do
      fields { field :post_id, :integer; field :tag_id, :integer }
      relationships { belongs_to :post; belongs_to :tag }
    end

    # This code can now run successfully
    @post1 = @db[:posts].create(title: 'Post 1')
    @post2 = @db[:posts].create(title: 'Post 2')
    @tag1 = @db[:tags].create(name: 'ruby')
    @tag2 = @db[:tags].create(name: 'dami')
    @db[:posts_tags].create(post_id: @post1[:id], tag_id: @tag1[:id])
    @db[:posts_tags].create(post_id: @post1[:id], tag_id: @tag2[:id])
    @db[:posts_tags].create(post_id: @post2[:id], tag_id: @tag2[:id])
  end
  
  def test_lazy_load_has_many_through
    post1 = @db[:posts].find(@post1[:id])
    tag_names = post1.tags.map { |t| t[:name] }.sort
    assert_equal ["dami", "ruby"], tag_names
  end

  def test_lazy_load_from_other_side
    tag2 = @db[:tags].find(@tag2[:id])
    post_titles = tag2.posts.map { |p| p[:title] }.sort
    assert_equal ["Post 1", "Post 2"], post_titles
  end

  def test_preload_has_many_through
    posts = @db[:posts].preload(:tags).to_a
    post1 = posts.find { |p| p[:id] == @post1[:id] }
    post2 = posts.find { |p| p[:id] == @post2[:id] }
    assert_equal 2, post1.tags.length
    assert_equal ["dami", "ruby"], post1.tags.map { |t| t[:name] }.sort
    assert_equal 1, post2.tags.length
    assert_equal ["dami"], post2.tags.map { |t| t[:name] }.sort
  end
end