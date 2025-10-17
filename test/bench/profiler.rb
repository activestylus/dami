# frozen_string_literal: true
require 'fileutils'
require 'ruby-prof'
require_relative '../../lib/dami'

# --- Configuration ---
DB_PATH = 'workflow_profile.db'
PROFILE_ITERATIONS = 20 # How many full workflows to run

# --- Setup ---
def setup_workflow_db
  FileUtils.rm_f(DB_PATH)
  Dami.connect(:workflow, adapter: :sqlite, path: DB_PATH)

  # Define a full set of models for a realistic scenario
  Dami.model(:users) do
    database :workflow
    fields { field :name, :string; field :email, :string }
    relationships { has_many :posts }
  end
  Dami.model(:posts) do
    database :workflow
    fields { field :user_id, :integer; field :title, :string; field :content, :text }
    relationships { belongs_to :user; has_many :comments }
    nests :comments, allow_destroy: true
  end
  Dami.model(:comments) do
    database :workflow
    fields { field :post_id, :integer; field :content, :text }
    relationships { belongs_to :post; has_many :attachments }
    nests :attachments, allow_destroy: true
    validate { rule :content, :required }
  end
  Dami.model(:attachments) do
    database :workflow
    fields { field :comment_id, :integer; field :filename, :string }
    relationships { belongs_to :comment }
    validate { rule :filename, :required }
  end

  # Create Schema
  db = Dami.database(:workflow)
  db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT);")
  db.execute("CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER, title TEXT, content TEXT);")
  db.execute("CREATE TABLE comments (id INTEGER PRIMARY KEY, post_id INTEGER, content TEXT);")
  db.execute("CREATE TABLE attachments (id INTEGER PRIMARY KEY, comment_id INTEGER, filename TEXT);")

  puts "Workflow profiler database ready."
end

# --- The Workflow to be Profiled ---
def run_workflow
  # 1. WRITE: Create a user and some nested posts/comments
  user = Dami.db(:users).create(name: 'Test User', email: 'test@example.com')
  Dami.db(:posts).create(
    user_id: user[:id],
    title: 'First Post',
    content: 'This is the first post.',
    comments_attributes: [
      { content: 'A great comment!', attachments_attributes: [{ filename: 'image.jpg' }] },
      { content: 'Another comment.' }
    ]
  )
  Dami.db(:posts).create(user_id: user[:id], title: 'Second Post')

  # 2. READ: Fetch the data back with preloads
  user_posts = Dami.db(:posts).where(user_id: user[:id]).preload(comments: :attachments).to_a
  
  # 3. UPDATE: Change the user's name and a nested comment, destroy an attachment
  first_comment_id = user_posts.first.comments.first[:id]
  first_attachment_id = user_posts.first.comments.first.attachments.first[:id]

  Dami.db(:posts).where(id: user_posts.first[:id]).update(
    title: 'Updated First Post',
    comments_attributes: {
      "0" => { id: first_comment_id, content: 'An edited comment' },
      "1" => { content: 'A newly added comment!' },
      "2" => { id: first_attachment_id, _destroy: '1' } # This key is for the attachment, but applied via comments
    }
  )

  # 4. DESTROY: Delete one of the posts
  Dami.db(:posts).where(id: user_posts.last[:id]).delete
end

# --- Profiling Execution ---
puts "\n--- Profiling Full Application Workflow (#{PROFILE_ITERATIONS} iterations) ---"

result = RubyProf.profile do
  PROFILE_ITERATIONS.times do
    # Run the entire setup and workflow inside the profiler
    # to capture all costs, including model definition and schema creation.
    setup_workflow_db
    run_workflow
  end
end

# --- Output ---
puts "\n--- Flat Profile (End-to-End) ---"
printer_flat = RubyProf::FlatPrinter.new(result)
printer_flat.print(STDOUT, sort_method: :total_time, min_percent: 1.0)
