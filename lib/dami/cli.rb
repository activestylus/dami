# File: ./lib/dami/cli.rb

# frozen_string_literal: true
require 'thor'
require 'fileutils'
require_relative '../dami' # Load the main Dami library

module Dami
  # 1. Define the parent namespace first to prevent loading errors.
  class CLI < Thor; end

  # 2. Define a base class for our subcommands to share common helper methods.
  class CLI::Base < Thor
    private

    # This helper loads the user's application environment. It looks for a
    # standard initializer and then loads all model files from the configured path.
    def load_user_app
      initializer_path = File.expand_path("config/initializers/dami.rb", Dir.pwd)
      require initializer_path if File.exist?(initializer_path)
      
      model_paths = Array(Dami.configuration.models_path)
      model_paths.each do |path|
        search_path = File.expand_path(path)
        Dir.glob(File.join(search_path, '**', '*.rb')).each { |file| load file }
      end
    end
  end

  # 3. Define the subcommand classes.

  # Handles all `dami db:*` subcommands.
  class DB < CLI::Base
    desc "migrate", "Run all pending database migrations"
    def migrate
      load_user_app
      puts "Running migrations..."
      
      db = Dami.database(:default) # Assumes the app has already connected.
      migrator = Dami::Migrator.new(db)
      migrator.migrate
      
      puts "✅ Migrations complete. Schema has been updated in #{Dami.configuration.schema_path}."
    end
    
    desc "rollback [STEPS]", "Revert the last migration (or the last STEPS migrations)"
    def rollback(steps = 1)
      load_user_app
      db = Dami.database(:default)
      Dami::Migrator.new(db).rollback(steps.to_i)
      puts "✅ Rolled back #{steps} migration(s). Schema has been updated in #{Dami.configuration.schema_path}."
    end

    desc "schema_dump", "Generate a schema file from the current database state"
    def schema_dump
      load_user_app
      puts "Dumping schema..."
      
      db = Dami.database(:default)
      dumper = Dami::Schema::Dumper.new(db)
      schema_content = dumper.dump

      schema_path = Dami.configuration.schema_path
      FileUtils.mkdir_p(File.dirname(schema_path))
      File.write(schema_path, schema_content)
      puts "✅ Schema dumped to #{schema_path}"
    end
  end

  # Handles all `dami generate *` subcommands.
  class Generate < CLI::Base
    desc "migration NAME", "Generate a new migration by comparing models to the schema"
    def migration(name)
      load_user_app
      
      loader = Dami::Schema::Loader.new
      loader.load_from_path(Dami.configuration.schema_path)
      
      introspector = Dami::Schema::Introspector.new
      
      differ = Dami::Schema::Diff.new(loader.schema, introspector.introspect)
      diff_result = differ.diff

      if diff_result[:up].empty?
        puts "✅ Schema is up to date. No migration generated."
      else
        generator = Dami::Schema::Generator.new
        path = generator.generate(diff_result, name)
        puts "✅ New migration created: #{path}"
      end
    end
  end

  # 4. Finally, reopen the main CLI class to add the subcommands.
  #    This works because `DB` and `Generate` are now fully defined.
  class CLI < Thor
    desc "db", "Manage database tasks (migrate, rollback, schema_dump)"
    subcommand "db", DB

    desc "generate", "Generate new files (e.g., migrations)"
    subcommand "generate", Generate
  end
end

# This modification to the Configuration class is still needed.
# It ensures the CLI has a place to get database connection details from.
class Dami::Configuration
  attr_accessor :database_config

  # We redefine initialize to add the new attribute with a default.
  def initialize
    @models_path = 'app/models'
    @migrations_path = 'db/migrations'
    @schema_path = 'db/schema.rb'
    @database_config = {}
  end
end