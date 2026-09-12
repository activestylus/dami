# frozen_string_literal: true
require_relative 'test_helper'
class PolymorphicTest < Minitest::Test
  def setup
    super
    # THE FIX: Make this test self-contained.
    Dami.model(:users) { fields { field :first_name, :string } }
    Dami.model(:posts) { fields { field :user_id, :integer; field :title, :string }; relationships { has_many comments: { as: :commentable, model: :comments } } }
    Dami.model(:articles) { fields { field :name, :string }; relationships { has_many comments: { as: :commentable, model: :comments } } }
    Dami.model(:comments) { fields { field :content, :text; field :commentable_id, :integer; field :commentable_type, :string }; relationships { belongs_to commentable: { polymorphic: true } } }

    user = @db[:users].create(first_name: 'Test')
    @post = @db[:posts].create(title: "My Post", user_id: user.id)
    @article = @db[:articles].create(name: "My Article")
    @comment1 = @db[:comments].create(content: "On Post", commentable_id: @post[:id], commentable_type: "Post")
    @comment2 = @db[:comments].create(content: "On Article", commentable_id: @article[:id], commentable_type: "Article")
  end

  # No changes needed to the test methods themselves
  def test_lazy_load_polymorphic_belongs_to
    comment = @db[:comments].find(@comment1[:id])
    assert_equal "My Post", comment.commentable[:title]
  end
  def test_lazy_load_polymorphic_has_many
    post = @db[:posts].find(@post[:id])
    assert_equal 1, post.comments.length
    assert_equal "On Post", post.comments.first[:content]
  end
  def test_preload_polymorphic_belongs_to
    comments = @db[:comments].preload(:commentable).to_a
    comment_on_post = comments.find { |c| c[:id] == @comment1[:id] }
    comment_on_article = comments.find { |c| c[:id] == @comment2[:id] }
    assert_equal "My Post", comment_on_post.commentable[:title]
    assert_equal "My Article", comment_on_article.commentable[:name]
  end
  def test_preload_polymorphic_has_many
    posts = @db[:posts].preload(:comments).to_a
    articles = @db[:articles].preload(:comments).to_a
    assert_equal 1, posts.first.comments.length
    assert_equal "On Post", posts.first.comments.first[:content]
    assert_equal 1, articles.first.comments.length
    assert_equal "On Article", articles.first.comments.first[:content]
  end
end