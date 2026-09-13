# File: ./test/cli_test.rb

require_relative 'test_helper'

class CliTest < Minitest::Test
  # ... (setup and teardown methods are correct)
  def setup
    super
    @app_root = File.expand_path('tmp_cli_app', __dir__)
    FileUtils.mkdir_p(File.join(@app_root, 'app', 'models'))
    FileUtils.mkdir_p(File.join(@app_root, 'db', 'migrations'))
    FileUtils.mkdir_p(File.join(@app_root, 'config', 'initializers'))
  end

  def teardown
    FileUtils.rm_rf(@app_root)
  end


  def test_generate_migration_for_added_column
    # --- ARRANGE ---
    
    # a. Create a Dami initializer file.
    initializer_content = <<~RUBY
      require 'dami'
      Dami.configure do |config|
        config.models_path = 'app/models'
        config.migrations_path = 'db/migrations'
        config.schema_path = 'db/schema.rb'
      end
    RUBY
    File.write(File.join(@app_root, 'config', 'initializers', 'dami.rb'), initializer_content)
    
    # b. Create the "old" schema file.
    initial_schema = <<~RUBY
      Dami.define_schema do
        create_table "users" do |t|
          t.field "name", :string
        end
      end
    RUBY
    File.write(File.join(@app_root, 'db', 'schema.rb'), initial_schema)
    
    # c. Create the "new" model file with a change.
    model_definition = <<~RUBY
      Dami.model :users do
        fields { field :name, :string; field :email, :string }
      end
    RUBY
    File.write(File.join(@app_root, 'app', 'models', 'user.rb'), model_definition)
    
    # d. Define the path to our CLI executable.
    cli_path = File.expand_path('../bin/dami', __dir__)

    # --- ACT ---

    # e. Run the CLI command from WITHIN the temporary app's directory.
    output = nil
    Dir.chdir(@app_root) do
      output = `#{cli_path} generate migration AddEmailToUsers`
    end
    
    # --- ASSERT ---

    # f. Check the command's output.
    assert_includes output, "✅ New migration created"
    
    # g. Find the generated migration file.
    migrations_dir = File.join(@app_root, 'db', 'migrations')
    migration_files = Dir.glob(File.join(migrations_dir, '*_add_email_to_users.rb'))
    
    assert_equal 1, migration_files.length, "A migration file should have been created in the temp directory"
    
    # h. Check the file's content.
    migration_content = File.read(migration_files.first)
    assert_includes migration_content, "add_column(:users, :email, :string)"
    assert_includes migration_content, "remove_column(:users, :email)"
  end
end