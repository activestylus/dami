# frozen_string_literal: true
require 'fileutils'
require 'ruby-prof'
require_relative '../../lib/dami'

# --- Configuration ---
DB_PATH = 'preload_profile.db'
NUM_USERS = 500
NUM_POSTS_PER_USER = 10
PROFILE_ITERATIONS = 50 # Number of times to run the preload operation

# --- Setup ---
def setup_profile_db
  FileUtils.rm_f(DB_PATH)
  Dami.connect(:profile_db, adapter: :sqlite, path: DB_PATH)

  Dami.model(:users) do
    database :profile_db
    fields { field :name, :string }
    relationships { has_many :posts }
  end
  Dami.model(:posts) do
    database :profile_db
    fields { field :user_id, :integer; field :title, :string }
    relationships { belongs_to :user }
  end

  db = Dami.database(:profile_db)
  db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);")
  db.execute("CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER, title TEXT);")

  puts "Setting up profiler DB..."
  users_data = (1..NUM_USERS).map { |i| { name: "User #{i}" } }
  Dami.db(:users).create_many(users_data)
  posts_data = (1..NUM_USERS).flat_map do |user_id|
    (1..NUM_POSTS_PER_USER).map { |i| { user_id: user_id, title: "Post #{i}" } }
  end
  Dami.db(:posts).create_many(posts_data)
  puts "Setup complete."
end

setup_profile_db

# --- Profiling ---
puts "\n--- Profiling Dami Preload Object Instantiation (#{PROFILE_ITERATIONS} iterations) ---"

result = RubyProf.profile do
  PROFILE_ITERATIONS.times do
    # The code being profiled: loading 100 posts and their users
    posts = Dami.db(:posts).preload(:user).limit(100).to_a
    # We don't need to iterate here; the cost is in the .to_a call which triggers preload.
  end
end

# --- Output ---
puts "\n--- Flat Profile ---"
printer_flat = RubyProf::FlatPrinter.new(result)
printer_flat.print(STDOUT, sort_method: :total_time, min_percent: 0.5)

puts "\n--- Graph Profile ---"
printer_graph = RubyProf::GraphPrinter.new(result)
printer_graph.print(STDOUT, min_percent: 0.5)

puts "\n--- Call Tree Profile ---"
# This can be very verbose but shows the call stack.
# printer_tree = RubyProf::CallTreePrinter.new(result)
# File.open("preload_callgrind.out", "w") { |f| printer_tree.print(f) }
# puts "Call tree profile saved to preload_callgrind.out (can be viewed with KCachegrind)"