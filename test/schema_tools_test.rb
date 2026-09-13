# File: ./test/schema_tools_test.rb

require_relative 'test_helper'

class SchemaToolsTest < Minitest::Test
  def setup
    super
    @expected_schema_hash = {
      "users" => {
        columns: {
          "name" => { type: :string },
          "email" => { type: :string }
        },
        indexes: {}
      },
      "posts" => {
        columns: {
          "title" => { type: :string },
          "user_id" => { type: :integer }
        },
        indexes: {
          "user_id" => {}
        }
      }
    }
  end

  def test_schema_loader_parses_correctly
    schema_content = <<~RUBY
      Dami.define_schema do
        create_table "users" do |t|
          t.field "name", :string
          t.field "email", :string
        end
        create_table "posts" do |t|
          t.field "title", :string
          t.field "user_id", :integer
        end
        add_index "posts", "user_id"
      end
    RUBY

    File.write("tmp_schema.rb", schema_content)
    
    loader = Dami::Schema::Loader.new
    loader.load_from_path("tmp_schema.rb")
    
    assert_equal @expected_schema_hash, loader.schema
  ensure
    FileUtils.rm_f("tmp_schema.rb")
  end

  def test_model_introspector_builds_correctly
    # Reset the global model registry to isolate this test.
    Dami.instance_variable_set(:@models, {})

    # Define models that represent our expected schema
    Dami.model :users do
      fields { field :name, :string; field :email, :string }
    end
    Dami.model :posts do
      fields { field :title, :string; field :user_id, :integer }
      relationships { belongs_to :user }
    end

    introspector = Dami::Schema::Introspector.new
    introspected_schema = introspector.introspect

    assert_equal @expected_schema_hash, introspected_schema
  end
end