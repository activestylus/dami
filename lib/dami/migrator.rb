# lib/dami/migrator.rb
# frozen_string_literal: true
module Dami
  class Migrator
    def initialize(adapter, path: Dami.configuration.migrations_path)
      @adapter = adapter
      @path = path
      ensure_schema_migrations_table
    end
    
    def migrate
      pending_migrations.each { |m| run_migration(m) }
      dump_schema
    end
    
    def rollback(steps = 1)
      completed_migrations.reverse.first(steps).each { |m| reverse_migration(m) }
      dump_schema
    end
    
    private

    def ensure_schema_migrations_table
      return if @adapter.table_exists?(:schema_migrations)
      
      @adapter.execute <<-SQL
        CREATE TABLE schema_migrations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          version VARCHAR(255) NOT NULL UNIQUE,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      SQL
    end
    
    def all_migrations
      return [] unless Dir.exist?(@path)
      Dir.glob("#{@path}/*.rb").sort.map do |file|
        version = File.basename(file).match(/^(\d+)_/)[1]
        { version: version, file: file }
      end
    end
    
    def completed_versions
      query = { 
        model_name: :schema_migrations, 
        conditions: [], 
        order_by: nil, 
        limit: nil, 
        offset: nil 
      }
      @adapter.query_records(query).map { |r| r[:version] }
    end
    
    def pending_migrations
      all_migrations.reject { |m| completed_versions.include?(m[:version]) }
    end
    
    def completed_migrations
      all_migrations.select { |m| completed_versions.include?(m[:version]) }
    end
    
    def load_migration(file)
      migration = Migration.new(@adapter)
      # This part is flexible; it will define up/down methods if they exist.
      migration.instance_eval(File.read(file), file)
      migration
    end
    
    def run_migration(migration_info)
      migration = load_migration(migration_info[:file])
      @adapter.transaction do
        migration.up
        @adapter.insert_record(:schema_migrations, { version: migration_info[:version] })
      end
    end
    
    def reverse_migration(migration_info)
      migration = load_migration(migration_info[:file])
      @adapter.transaction do
        migration.down
        
        @adapter.execute(
          "DELETE FROM schema_migrations WHERE version = ?",
          [migration_info[:version]]
        )
      end
    rescue => e
      puts "Error in reverse_migration for #{migration_info[:version]}: #{e.message}"
      puts e.backtrace.first(5)
      raise
    end
    def dump_schema
      require_relative 'schema/dumper'
      dumper = Dami::Schema::Dumper.new(@adapter)
      schema_content = dumper.dump
      
      # Use the configured path.
      schema_path = Dami.configuration.schema_path
      FileUtils.mkdir_p(File.dirname(schema_path))
      File.write(schema_path, schema_content)
    end
  end
end