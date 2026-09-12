# File: ./test/database_helper.rb

# frozen_string_literal: true
# Conditionally require gems for the selected database
case ENV['DB']
when 'postgres'
  require 'pg'
when 'mysql'
  require 'mysql2'
end

module DatabaseHelper
  def self.adapter_name
    (ENV['DB'] || 'sqlite').to_sym
  end

  def self.config
    {
      sqlite: { adapter: :sqlite, path: "test_db.sqlite3" },
      postgres: { adapter: :postgres, host: 'localhost', user: 'postgres', password: '', dbname: 'dami_test' },
      mysql: { adapter: :mysql, host: 'localhost', user: 'root', password: '', database: 'dami_test' }
    }[adapter_name]
  end

  def self.pk_type
    case adapter_name
    when :postgres then 'SERIAL PRIMARY KEY'
    when :mysql then 'INTEGER PRIMARY KEY AUTO_INCREMENT'
    else 'INTEGER PRIMARY KEY'
    end
  end

  def self.datetime_type
    adapter_name == :postgres ? 'TIMESTAMP' : 'DATETIME'
  end

  def self.define_schema(db)
    pk = pk_type
    dt = datetime_type
    db.execute("CREATE TABLE users (id #{pk}, first_name TEXT, last_name TEXT, email TEXT, bio TEXT, password_hash TEXT, account_type TEXT, ssn TEXT, role TEXT, status TEXT, age INTEGER, created_at #{dt});")
    db.execute("CREATE TABLE profiles (id #{pk}, user_id INTEGER, bio TEXT);")
    db.execute("CREATE TABLE posts (id #{pk}, user_id INTEGER, title TEXT, published_at #{dt}, status TEXT, content TEXT, published BOOLEAN);")
    db.execute("CREATE TABLE tags (id #{pk}, name TEXT);")
    db.execute("CREATE TABLE posts_tags (id #{pk}, post_id INTEGER, tag_id INTEGER);")
    db.execute("CREATE TABLE articles (id #{pk}, name TEXT);")
    db.execute("CREATE TABLE comments (id #{pk}, content TEXT, commentable_id INTEGER, commentable_type TEXT, post_id INTEGER, sticky BOOLEAN);") # ADDED sticky
    db.execute("CREATE TABLE attachments (id #{pk}, comment_id INTEGER, filename TEXT);")
    db.execute("CREATE INDEX IF NOT EXISTS idx_comments_on_commentable ON comments (commentable_type, commentable_id);")
  end


  def self.drop_all_tables(db)
    case adapter_name
    when :sqlite
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
      # Foreign keys are enforced, so drop everything in one transaction with
      # deferred checks: by commit time no table (and no violation) is left.
      db.transaction do
        db.execute("PRAGMA defer_foreign_keys = ON")
        tables.each { |row| db.execute("DROP TABLE IF EXISTS #{row['name']}") }
      end
    when :postgres
      db.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
    when :mysql
      tables = db.execute("SHOW TABLES;").map { |row| row.values.first }
      return if tables.empty?
      db.execute("SET FOREIGN_KEY_CHECKS = 0;")
      tables.each { |table| db.execute("DROP TABLE IF EXISTS `#{table}`;") }
      db.execute("SET FOREIGN_KEY_CHECKS = 1;")
    end
  end
end