# File: test/test_helper.rb

require "minitest/autorun"
require "minitest/reporters"
require "fileutils"
require_relative "../lib/dami"
require_relative "./database_helper"

Minitest::Reporters.use! [
  Minitest::Reporters::DefaultReporter.new(
    color: true,
    slow_count: 5,
    detailed_skip: false
  )
]

class Minitest::Test
def setup
  Dami.instance_variable_set(:@databases, {})
  Dami.instance_variable_set(:@models, {})
  self.class.register_validation_rules
  Dami.clear_all!
  self.class.register_validation_rules  # Register again after clear
  config = DatabaseHelper.config
  @db = Dami.connect(:default, **config)
  DatabaseHelper.drop_all_tables(@db)
  DatabaseHelper.define_schema(@db)
  self.class.define_all_models
end

def teardown
  DatabaseHelper.drop_all_tables(@db) if @db
end

  def self.cleanup_database_files(base_path)
    base = base_path.to_s.gsub(/\.db$/, '')
    ["#{base}.db", "#{base}.db-shm", "#{base}.db-wal", "#{base}.db-journal"].each do |file|
      FileUtils.rm_f(file) if File.exist?(file)
    end
  end

  def self.register_validation_rules
    Dami.register_default_rules!
  end

  def self.define_all_models
    # === STRUCTURE (Dami.model) ===
    
    Dami.model :users do
      fields do
        field :first_name, :string
        field :last_name, :string
        field :email, :string
        field :bio, :text
        field :password_hash, :string
        field :account_type, :string
        field :ssn, :string
        field :role, :string
        field :status, :string
        field :age, :integer
        field :created_at, :datetime
      end
      
      virtual do
        field :password, :string
        field :password_confirmation, :string
        field :terms_accepted, :boolean
      end
      
      relationships do
        has_one :profile
        has_many :posts
      end
    end

    # === BEHAVIOR (Dami.behavior) ===
    
    Dami.behavior :users do
      protection do
        protect :role
        permit :status
      end
      
      validate do
        rule :first_name, :required
        rule :status, inclusion: %w[active inactive]
      end
    end

    # === SCOPES (Dami.scopes) ===
    
    Dami.scopes :users do
      scope :active, -> { where(status: 'active') }
      scope :admins, -> { where(role: 'admin') }
      scope :by_status, ->(status) { where(status: status) }
      scope :recent, -> { where(created_at: { gt: Time.now - 86_400 }) }
    end

    # === OTHER MODELS ===
    
    Dami.model(:profiles) do
      fields { field :user_id, :integer; field :bio, :text }
      relationships { belongs_to :user }
    end

    Dami.model(:posts) do
      fields do
        field :user_id, :integer
        field :title, :string
        field :published_at, :datetime
        field :status, :string
        field :content, :text
        field :published, :boolean
      end
      
      relationships do
        belongs_to :user
        has_many :posts_tags
        has_many :tags, through: :posts_tags
        has_many :comments, as: :commentable
      end
    end
    
    Dami.scopes(:posts) do
      scope :published, -> { where(status: 'published') }
      scope :drafts, -> { where(status: 'draft') }
      scope :recent, -> { where(published_at: { gt: Time.now - 604_800 }) }
    end

    Dami.model(:tags) do
      fields { field :name, :string }
      relationships do
        has_many :posts_tags
        has_many :posts, through: :posts_tags
      end
    end

    Dami.model(:posts_tags) do
      fields { field :post_id, :integer; field :tag_id, :integer }
      relationships { belongs_to :post; belongs_to :tag }
    end

    Dami.model(:articles) do
      fields { field :name, :string }
      relationships { has_many :comments, as: :commentable }
    end

    Dami.model(:comments) do
      fields { field :content, :text; field :commentable_id, :integer; field :commentable_type, :string; field :post_id, :integer; field :sticky, :boolean }
      relationships { belongs_to :commentable, polymorphic: true }
    end
  end
end
Minitest.after_run do
  sleep 0.1
  if DatabaseHelper.adapter_name == :sqlite
    Minitest::Test.cleanup_database_files(DatabaseHelper.config[:path])
  end
end