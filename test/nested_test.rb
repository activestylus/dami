# frozen_string_literal: true
require_relative 'test_helper'

class NestedAttributesTest < Minitest::Test
  def setup
    super
    Dami.model :posts do
      fields { field :title, :string }
      relationships { has_many :comments }
      nests :comments, allow_destroy: true
    end
    Dami.model :comments do
      fields { field :post_id, :integer; field :content, :text; field :sticky, :boolean }
      relationships { belongs_to :post; has_many :attachments }
      nests :attachments
      validate do
        rule :content, :required, min_length: 3
      end
      protection do
        protect :sticky
      end
    end
    Dami.model :attachments do
      fields { field :comment_id, :integer; field :filename, :string }
      relationships { belongs_to :comment }
      validate { rule :filename, :required }
    end
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
  existing_posts_config = Dami.find_model(:posts)
  existing_posts_config[:validations] ||= {}
  existing_posts_config[:validations][:title] = { required: true }

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
  # Create a second, distinct comment that we can safely destroy.
  comment_to_destroy = @db[:comments].create(post_id: @post[:id], content: 'Delete Me')
  @db[:posts].where(id: @post[:id]).update(
    title: 'Updated Parent',
    comments_attributes: [
      # Action 1: Update the original comment
      { id: @comment[:id], content: 'Updated Existing Comment' },
      # Action 2: Create a new comment
      { content: 'A Brand New Comment' },
      # Action 3: Destroy the second comment
      { id: comment_to_destroy[:id], _destroy: '1' }
    ]
  )
  
  # Debug: Check all comments
  all_comments = @db[:comments].where(post_id: @post[:id]).to_a
  reloaded_post = @db[:posts].find(@post[:id])
  assert_equal 'Updated Parent', reloaded_post[:title]
  
  comments = @db[:comments].where(post_id: reloaded_post[:id]).order(:id)
  assert_equal 2, comments.length
  assert_equal 'Updated Existing Comment', comments.first[:content]
  assert_equal 'A Brand New Comment', comments.last[:content]

  # Verify the specific "Delete Me" comment was deleted by checking all comments
  deleted_comment_still_exists = all_comments.any? { |c| c[:content] == 'Delete Me' }
  refute deleted_comment_still_exists, "The comment with content 'Delete Me' should have been deleted."
  
  # The comment with the original ID might still exist but with different content
  # (if the database reused the ID)
  comment_with_old_id = @db[:comments].find(comment_to_destroy[:id])
  if comment_with_old_id
    refute_equal 'Delete Me', comment_with_old_id[:content], "The old ID was reused but content should be different"
  end
end

  def test_update_ignores_destroy_on_new_nested_record
    initial_comment_count = @db[:comments].where(post_id: @post[:id]).count

    @db[:posts].where(id: @post[:id]).update(
      comments_attributes: [
        # This new record marked for destruction should be ignored
        { content: 'I should be ignored', _destroy: '1' },
        # This new record should be created successfully
        { content: 'I should be created' }
      ]
    )

    final_comment_count = @db[:comments].where(post_id: @post[:id]).count
    new_comment = @db[:comments].where(post_id: @post[:id], content: 'I should be created').first

    assert_equal initial_comment_count + 1, final_comment_count, "Should only create one new comment"
    refute_nil new_comment, "The valid new comment should have been created"
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
end