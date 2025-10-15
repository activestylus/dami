# File: ./test/test_helper.rb

# frozen_string_literal: true
require "minitest/autorun"
require "minitest/reporters"
require "fileutils"
require_relative "../lib/dami"
require_relative "./database_helper"

# Use your preferred reporter setup
Minitest::Reporters.use! [
  Minitest::Reporters::DefaultReporter.new(
    color: true,
    slow_count: 5,
    detailed_skip: false
  )
]

class Minitest::Test
  # This setup method runs before EVERY single test, guaranteeing a clean slate.
  def setup
    # 1. Reset Dami's global state to prevent pollution between tests.
    Dami.instance_variable_set(:@databases, {})
    Dami.instance_variable_set(:@models, {})

    # 2. Register validation rules so models can be defined correctly.
    self.class.register_validation_rules

    # 3. Connect to the database. For SQLite, this creates a new file if needed.
    config = DatabaseHelper.config
    @db = Dami.connect(:default, **config)

    # 4. WIPE THE DATABASE CLEAN. This is the most important step.
    DatabaseHelper.drop_all_tables(@db)

    # 5. Create the schema on the now-guaranteed-empty database.
    DatabaseHelper.define_schema(@db)

    # 6. Define all models for the current test.
    self.class.define_all_models
  end

  def teardown
    # Close the connection pool after each test.
    if @db
      pool = @db.instance_variable_get(:@connection_pool)
      pool&.shutdown(&:close)
    end
  end

  # THIS IS THE MISSING METHOD. It's defined here so all test classes can use it.
  def self.cleanup_database_files(base_path)
    base = base_path.to_s.gsub(/\.db$/, '')
    ["#{base}.db", "#{base}.db-shm", "#{base}.db-wal", "#{base}.db-journal"].each do |file|
      FileUtils.rm_f(file) if File.exist?(file)
    end
  end

  # --- Other Helper Methods ---

  def self.register_validation_rules
    Dami.rules :default, {
      required: { check: ->(v) { !v.nil? && !v.to_s.strip.empty? }, message: "is required" },
      presence: { check: ->(v) { !v.nil? && !v.to_s.strip.empty? }, message: "is required" },
      email: { check: ->(v) { v.to_s =~ /\A[^@\s]+@[^@\s]+\z/ }, message: "must be valid email" },
      format: ->(p) { { check: ->(v) { v.nil? || v.to_s.match?(p) }, message: "has invalid format" } },
      inclusion: ->(vals) { { check: ->(v) { vals.include?(v) }, message: "is not in the list of accepted values" } },
      min_length: ->(min) { { check: ->(v) { v.to_s.length >= min }, message: "must be at least #{min} characters" } }
    }
  end

  def self.define_all_models
    Dami.model :users do
      fields do
        field :name, :string; field :email, :string; field :bio, :text
        field :password_hash, :string; field :account_type, :string; field :ssn, :string
        field :role, :string; field :status, :string; field :age, :integer; field :created_at, :datetime
      end
      virtual do
        field :password, :string; field :password_confirmation, :string; field :terms_accepted, :boolean
      end
      relationships { has_one :profile; has_many :posts }
      protection { protect :role; permit :status }
      validate do
        rule :name, :required
        rule :status, inclusion: %w[active inactive]
      end
      scopes do
        scope :active, -> { where(status: 'active') }
        scope :admins, -> { where(role: 'admin') }
        scope :by_status, ->(status) { where(status: status) }
        scope :recent, -> { where(created_at: { gt: Time.now - 86_400 }) }
      end
    end
    Dami.model(:profiles) { fields { field :user_id, :integer; field :bio, :text }; relationships { belongs_to :user } }
    Dami.model(:posts) { fields { field :user_id, :integer; field :title, :string; field :published_at, :datetime; field :status, :string; field :content, :text; field :published, :boolean }; relationships { belongs_to :user; has_many :posts_tags; has_many :tags, through: :posts_tags; has_many comments: { as: :commentable, model: :comments } }; scopes { scope :published, -> { where(status: 'published') }; scope :drafts, -> { where(status: 'draft') }; scope :recent, -> { where(published_at: { gt: Time.now - 604_800 }) } } }
    Dami.model(:tags) { fields { field :name, :string }; relationships { has_many :posts_tags; has_many :posts, through: :posts_tags } }
    Dami.model(:posts_tags) { fields { field :post_id, :integer; field :tag_id, :integer }; relationships { belongs_to :post; belongs_to :tag } }
    Dami.model(:articles) { fields { field :name, :string }; relationships { has_many comments: { as: :commentable, model: :comments } } }
    Dami.model(:comments) { fields { field :content, :text; field :commentable_id, :integer; field :commentable_type, :string }; relationships { belongs_to commentable: { polymorphic: true } } }
  end
end

# A final cleanup after the entire suite is done.
Minitest.after_run do
  if DatabaseHelper.adapter_name == :sqlite
    Minitest::Test.cleanup_database_files(DatabaseHelper.config[:path])
  end
end