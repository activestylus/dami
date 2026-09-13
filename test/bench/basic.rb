# frozen_string_literal: true
require 'benchmark/ips'
require 'fileutils'
require_relative '../../lib/dami'

def setup_benchmark_database
  db_path = 'benchmark.db'
  FileUtils.rm_f(db_path)
  Dami.connect(:benchmark, adapter: :sqlite, path: db_path)

  # The models use the :benchmark database explicitly.
  Dami.model(:users) do
    database :benchmark
    fields { field :name, :string }
    relationships { has_many :posts }
  end

  Dami.model(:posts) do
    database :benchmark
    fields { field :user_id, :integer; field :title, :string }
    relationships { belongs_to :user }
  end

  db = Dami.database(:benchmark)
  db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);")
  db.execute("CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER, title TEXT);")

  puts "Setting up benchmark database with 1,000 users and 10,000 posts..."
  
  users_to_create = (1..1000).map { |i| { name: "User #{i}" } }
  # Through the Dami API, not the raw connection.
  Dami.db(:users).create_many(users_to_create)
  
  posts_to_create = (1..1000).flat_map do |user_id|
    (1..10).map { |i| { user_id: user_id, title: "Post #{i} by User #{user_id}" } }
  end
  Dami.db(:posts).create_many(posts_to_create)
  
  puts "Setup complete."
end

setup_benchmark_database
USER_IDS = (1..1000).to_a.freeze

Benchmark.ips do |b|
  b.warmup = 2
  b.time = 5

  puts "\n--- Benchmarking Dami ORM ---\n"

  b.report("Create (single)") do
    Dami.db(:users).create(name: "Benchmark User")
  end

  b.report("Find (by id)") do
    Dami.db(:users).find(USER_IDS.sample)
  end

  b.report("Where (indexed)") do
    Dami.db(:posts).where(user_id: USER_IDS.sample).to_a
  end

  puts "\nComparing old vs. new .count method:"
  b.report("Count (old way)") do
    Dami.db(:posts).where(user_id: USER_IDS.sample).to_a.size
  end
  
  b.report("Count (optimized)") do
    Dami.db(:posts).where(user_id: USER_IDS.sample).count
  end

  puts "\nComparing N+1 query vs. .preload:"
  b.report("N+1 Query") do
    posts = Dami.db(:posts).limit(100).to_a
    posts.each { |post| post.user[:name] }
  end

  b.report("Preload") do
    posts = Dami.db(:posts).preload(:user).limit(100).to_a
    posts.each { |post| post.user[:name] }
  end

  b.compare!
end