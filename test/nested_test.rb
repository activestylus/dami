# frozen_string_literal: true
require_relative 'test_helper'

class NestedAttributesTest < Minitest::Test
  def setup
    super
    # --- Schema Definitions ---
    Dami.model :posts do
      fields { field :title, :string }
      relationships { has_many :comments }
      nests :comments, allow_destroy: true
    end
    Dami.model :comments do
      fields { field :post_id, :integer; field :content, :text; field :sticky, :boolean }
      relationships { belongs_to :post; has_many :attachments }
      nests :attachments
      
    end
    Dami.behavior :comments do
      protection { protect :sticky }
    end
    Dami.model :attachments do
      fields { field :comment_id, :integer; field :filename, :string }
      relationships { belongs_to :comment }
    end

    # --- Behavior Definitions ---
    Dami.behavior :comments do
      validate do
        rule :content, :required, min_length: 3
      end
    end
    Dami.behavior :attachments do
      validate { rule :filename, :required }
    end

    # --- Seed Data ---
    @post = @db[:posts].create(title: 'Parent Post')
    @comment = @db[:comments].create(post_id: @post[:id], content: 'Existing Comment')
    @attachment = @db[:attachments].create(comment_id: @comment[:id], filename: 'existing.file')
  end

  def test_create_with_nested_children
    post = @db[:posts].create(
      title: 'New Post',
      comments_attributes: [
        { content: 'First comment' },
        { content: 'Second comment' }
      ]
    )
    assert_equal 'New Post', post[:title]
    assert_equal 2, @db[:comments].where(post_id: post[:id]).count
    assert_equal ['First comment', 'Second comment'], @db[:comments].where(post_id: post[:id]).order(:id).map { |c| c[:content] }
  end

  def test_grandchildren_are_processed
    post = @db[:posts].create(
      title: 'Test Grandchildren',
      comments_attributes: [{
        content: 'Parent Comment',
        attachments_attributes: [
          { filename: 'test1.txt' },
          { filename: 'test2.txt' }
        ]
      }]
    )
    comment = @db[:comments].where(post_id: post[:id]).first
    assert comment, "Comment should be created"
    attachments = @db[:attachments].where(comment_id: comment[:id])
    assert_equal 2, attachments.count, "Should create 2 attachments"
  end

  def test_create_with_deeply_nested_grandchildren
    post = @db[:posts].create(
      title: 'Deep Nest',
      comments_attributes: [{
        content: 'Comment with files',
        attachments_attributes: [
          { filename: 'file1.pdf' },
          { filename: 'file2.zip' }
        ]
      }]
    )
    assert post[:id]
    comment = @db[:comments].where(post_id: post[:id]).first
    assert comment
    assert_equal 'Comment with files', comment[:content]
    assert_equal 2, @db[:attachments].where(comment_id: comment[:id]).count
  end

  def test_create_fails_atomically_if_a_child_is_invalid
    initial_post_count = @db[:posts].count
    error = assert_raises(Dami::ValidationError) do
      @db[:posts].create(
        title: 'Good Post',
        comments_attributes: [
          { content: 'Good Comment' },
          { content: '' }
        ]
      )
    end
    assert_equal initial_post_count, @db[:posts].count, "No new post should have been created."
  end

  def test_create_fails_atomically_if_a_grandchild_is_invalid
    initial_counts = { posts: @db[:posts].count, comments: @db[:comments].count }
    assert_raises(Dami::ValidationError) do
      @db[:posts].create(
        title: 'Good Post',
        comments_attributes: [{
          content: 'Good Comment',
          attachments_attributes: [
            { filename: 'good.file' },
            { filename: '' }
          ]
        }]
      )
    end
    assert_equal initial_counts[:posts], @db[:posts].count
    assert_equal initial_counts[:comments], @db[:comments].count
    assert_equal 0, @db[:attachments].where(filename: 'good.file').count
  end

  def test_create_gathers_all_nested_errors_correctly
    Dami.behavior(:posts) { validate { rule :title, :required } }

    error = assert_raises(Dami::ValidationError) do
      @db[:posts].create(
        title: '',
        comments_attributes: [
          { content: 'Good Comment' },
          { content: '' },
          { content: 'Good Comment', attachments_attributes: [{ filename: '' }] }
        ]
      )
    end

    actual_errors = error.errors
    assert actual_errors.key?(:title), "Should have title errors"
    assert_equal ["is required"], actual_errors[:title]
    assert actual_errors.key?(:comments_attributes), "Should have comments_attributes errors. Full errors: #{actual_errors}"
    comments_errors = actual_errors[:comments_attributes]
    assert !comments_errors.empty?, "Should have at least one comment with errors"
    has_content_errors = comments_errors.values.any? { |comment_error| comment_error.key?(:content) && comment_error[:content].include?("is required") }
    assert has_content_errors, "Should have content validation errors"
    has_attachment_errors = comments_errors.values.any? { |comment_error| comment_error.key?(:attachments_attributes) && comment_error[:attachments_attributes].values.any? { |att| att.key?(:filename) } }
    assert has_attachment_errors, "Should have nested attachment validation errors"
  end

  def test_direct_deletion_works
    comment = @db[:comments].create(post_id: @post[:id], content: 'Test Delete')
    result = @db[:comments].where(id: comment[:id]).delete
    found = @db[:comments].find(comment[:id])
    assert_nil found, "Direct deletion should work"
  end

def test_update_with_mixed_nested_operations
    comment_to_destroy = @db[:comments].create(post_id: @post[:id], content: 'Delete Me')
    @db[:posts].where(id: @post[:id]).update(
      title: 'Updated Parent',
      comments_attributes: [
        { id: @comment[:id], content: 'Updated Existing Comment' },
        { content: 'A Brand New Comment' },
        { id: comment_to_destroy[:id], _destroy: '1' }
      ]
    )

    reloaded_post = @db[:posts].find(@post[:id])
    assert_equal 'Updated Parent', reloaded_post[:title]
    
    comments = @db[:comments].where(post_id: reloaded_post[:id]).order(:id)
    comment_contents = comments.map { |c| c[:content] }

    assert_equal 2, comments.length
    assert_includes comment_contents, 'Updated Existing Comment'
    assert_includes comment_contents, 'A Brand New Comment'
    
    # No comment with the old content may remain for this post.
    refute_includes comment_contents, 'Delete Me', "The 'Delete Me' comment should have been destroyed"
  end

  def test_update_with_empty_nested_attributes_does_nothing
    original_comment_count = @db[:comments].where(post_id: @post[:id]).count
    @db[:posts].where(id: @post[:id]).update(
      title: 'Updated Title Only',
      comments_attributes: []
    )
    reloaded_post = @db[:posts].find(@post[:id])
    assert_equal 'Updated Title Only', reloaded_post[:title]
    assert_equal original_comment_count, @db[:comments].where(post_id: @post[:id]).count
  end

  def test_destroy_is_ignored_when_allow_destroy_is_false
    @db[:comments].where(id: @comment[:id]).update(
      attachments_attributes: [{ id: @attachment[:id], _destroy: '1' }]
    )
    assert @db[:attachments].find(@attachment[:id]), "Attachment should NOT have been deleted."
  end

  def test_nested_child_respects_protection_rules
    assert_raises(Dami::ProtectionError) do
      @db[:posts].where(id: @post[:id]).update(
        comments_attributes: [{ content: 'Trying to be sticky', sticky: true }]
      )
    end
  end

  def test_permit_is_passed_down_to_nested_children
    @db[:posts].where(id: @post[:id]).update(
      comments_attributes: [{
        id: @comment[:id],
        content: 'This is now sticky',
        sticky: true
      }],
      permit: [:sticky]
    )
    reloaded_comment = @db[:comments].find(@comment[:id])
    assert_equal true, reloaded_comment[:sticky]
  end

  # From battle_test.rb
  def test_update_ignores_destroy_on_new_nested_record
    initial_comment_count = @db[:comments].where(post_id: @post[:id]).count
    @db[:posts].where(id: @post[:id]).update(
      comments_attributes: [
        { content: 'I should be ignored', _destroy: '1' },
        { content: 'I should be created' }
      ]
    )
    final_comment_count = @db[:comments].where(post_id: @post[:id]).count
    new_comment = @db[:comments].where(post_id: @post[:id], content: 'I should be created').first
    assert_equal initial_comment_count + 1, final_comment_count, "Should only create one new comment"
    refute_nil new_comment, "The valid new comment should have been created"
  end

  def test_update_with_string_keys_for_id_and_destroy
    comment_to_destroy = @db[:comments].create(post_id: @post[:id], content: 'Delete Me')
    @db[:posts].where(id: @post[:id]).update(
      comments_attributes: [
        { "id" => @comment[:id].to_s, "content" => "Updated with string keys" },
        { "id" => comment_to_destroy[:id].to_s, "_destroy" => "1" }
      ]
    )
    reloaded_comment = @db[:comments].find(@comment[:id])
    assert_equal "Updated with string keys", reloaded_comment[:content]
    assert_nil @db[:comments].find(comment_to_destroy[:id]), "Comment should be destroyed"
  end

  def test_update_ignores_nested_record_with_mismatched_parent_id
    post2 = @db[:posts].create(title: 'Another Post')
    comment_on_post2 = @db[:comments].create(post_id: post2[:id], content: 'Belongs to Post 2')

    @db[:posts].where(id: @post[:id]).update(
      comments_attributes: [{ id: comment_on_post2[:id], content: "Hijacked!" }]
    )
    reloaded_comment = @db[:comments].find(comment_on_post2[:id])
    assert_equal post2[:id], reloaded_comment[:post_id]
    assert_equal 'Belongs to Post 2', reloaded_comment[:content], "Comment should not have been updated or moved"
  end

  def test_update_with_nil_nested_attributes_does_nothing
    original_comment_count = @db[:comments].where(post_id: @post[:id]).count
    @db[:posts].where(id: @post[:id]).update(
      title: 'Updated Title Again',
      comments_attributes: nil
    )
    reloaded_post = @db[:posts].find(@post[:id])
    assert_equal 'Updated Title Again', reloaded_post[:title]
    assert_equal original_comment_count, @db[:comments].where(post_id: @post[:id]).count
  end
end
