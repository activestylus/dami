# frozen_string_literal: true
require 'benchmark/ips'
require 'fileutils'
require 'active_record'
require 'sequel'
require_relative '../../lib/dami'
require 'ruby-prof' # Add this require

# --- Configuration ---
DB_PATH = 'competitive_benchmark.db'
NUM_USERS = 500
NUM_POSTS_PER_USER = 10
TOTAL_POSTS = NUM_USERS * NUM_POSTS_PER_USER

# --- SETUP (Top Level) ---

# 1. Clean up and connect all ORMs.
FileUtils.rm_f(DB_PATH)
Dami.connect(:competitive, adapter: :sqlite, path: DB_PATH)
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: DB_PATH)
SEQ_DB = Sequel.sqlite(DB_PATH) # This is now a valid top-level constant.

# 2. Create the database schema BEFORE defining AR/Sequel models.
dami_db = Dami.database(:competitive)
dami_db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);")
dami_db.execute("CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER, title TEXT);")

# 3. Define all models.
# Dami
Dami.model(:users) do
  database :competitive
  fields { field :name, :string }
  relationships { has_many :posts }
end
Dami.model(:posts) do
  database :competitive
  fields { field :user_id, :integer; field :title, :string }
  relationships { belongs_to :user }
end

# ActiveRecord
class ArUser < ActiveRecord::Base
  self.table_name = 'users'
  has_many :ar_posts, class_name: 'ArPost', foreign_key: 'user_id'
end
class ArPost < ActiveRecord::Base
  self.table_name = 'posts'
  belongs_to :ar_user, class_name: 'ArUser', foreign_key: 'user_id'
end

# Sequel
class SeqUser < Sequel::Model(:users)
  one_to_many :seq_posts, class_name: :SeqPost, key: :user_id
end
class SeqPost < Sequel::Model(:posts)
  many_to_one :seq_user, class_name: :SeqUser, key: :user_id
end

# 4. Seed the database.
puts "Setting up benchmark DB with #{NUM_USERS} users and #{TOTAL_POSTS} posts..."
users_data = (1..NUM_USERS).map { |i| { name: "User #{i}" } }
Dami.db(:users).create_many(users_data)
posts_data = (1..NUM_USERS).flat_map do |user_id|
  (1..NUM_POSTS_PER_USER).map { |i| { user_id: user_id, title: "Post #{i} by User #{user_id}" } }
end
Dami.db(:posts).create_many(posts_data)
puts "Setup complete."

USER_IDS_COMP = (1..NUM_USERS).to_a.freeze
POST_IDS_COMP = (1..TOTAL_POSTS).to_a.freeze

# --- PROFILING ---
puts "\n--- Profiling Dami Preload ---"

# Profile the Dami preload operation
result = RubyProf.profile do
  100.times do # Run it multiple times for better data
    posts = Dami.db(:posts).preload(:user).limit(100).to_a
    posts.each { |p| p.user[:name] }
  end
end

# Print a flat profile report (sorted by total time)
printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT, sort_method: :total_time, min_percent: 1) # Show methods taking >= 1% of time


# --- BENCHMARKS ---
puts "\n--- Running Full Competitive Benchmarks ---"
Benchmark.ips do |b|
  b.warmup = 2
  b.time = 5
  puts "\n--- Competitive Benchmarks (SQLite) ---"

  puts "\nRecord Creation (Single):"
  b.report("Dami") { Dami.db(:users).create(name: "New Dami User") }
  b.report("ActiveRecord") { ArUser.create(name: "New AR User") }
  b.report("Sequel") { SeqUser.create(name: "New Seq User") }
  b.compare!

  puts "\nFinding by ID:"
  b.report("Dami") { Dami.db(:users).find(USER_IDS_COMP.sample) }
  b.report("ActiveRecord") { ArUser.find(USER_IDS_COMP.sample) }
  b.report("Sequel") { SeqUser[USER_IDS_COMP.sample] }
  b.compare!

  puts "\nSimple Where (Indexed user_id):"
  b.report("Dami") { Dami.db(:posts).where(user_id: USER_IDS_COMP.sample).to_a }
  b.report("ActiveRecord") { ArPost.where(user_id: USER_IDS_COMP.sample).to_a }
  b.report("Sequel") { SeqPost.where(user_id: USER_IDS_COMP.sample).all }
  b.compare!

  puts "\nAssociation Loading (100 Posts + User):"
  b.report("Dami (N+1)") do
    posts = Dami.db(:posts).limit(100).to_a
    posts.each { |p| p.user[:name] }
  end
  b.report("Dami (preload)") do
    posts = Dami.db(:posts).preload(:user).limit(100).to_a
    posts.each { |p| p.user[:name] }
  end
  b.report("ActiveRecord (N+1)") do
    posts = ArPost.limit(100).to_a
    posts.each { |p| p.ar_user.name }
  end
  b.report("ActiveRecord (includes)") do
    posts = ArPost.includes(:ar_user).limit(100).to_a
    posts.each { |p| p.ar_user.name }
  end
  b.report("Sequel (N+1)") do
    posts = SeqPost.limit(100).all
    posts.each { |p| p.seq_user.name }
  end
  b.report("Sequel (eager)") do
    posts = SeqPost.eager(:seq_user).limit(100).all
    posts.each { |p| p.seq_user.name }
  end
  b.compare!
end