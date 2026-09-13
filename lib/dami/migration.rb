# lib/dami/migration.rb — the schema DSL a migration file's up/down is written in

module Dami
  class Migration
    def initialize(adapter)
      @adapter = adapter
    end

    def up
      # This should be overridden by the migration file
    end

    def down
      # This should be overridden by the migration file
    end

    # Schema methods
    def create_table(name, &block)
      table_definition = TableDefinition.new

      # Support both styles: do |t| ... end and do ... end
      if block.arity == 0
        table_definition.instance_eval(&block)
      else
        yield table_definition
      end

      @adapter.create_table(name, table_definition.columns)
    end

    def drop_table(name)
      @adapter.execute("DROP TABLE IF EXISTS #{name}")
    end

    def add_column(table, column, type, **options)
      @adapter.add_column(table, column, type, **options)
    end

    def remove_column(table, column)
      # SQLite has limited DROP COLUMN support
      # This will work in SQLite 3.35.0+ but fail gracefully in older versions
      begin
        @adapter.execute("ALTER TABLE #{table} DROP COLUMN #{column}")
      rescue SQLite3::Exception => e
        # Log the limitation but don't crash
        puts "Note: DROP COLUMN not supported in this SQLite version: #{e.message}"
      end
    end

    def add_index(table_name, column_name, **options)
      @adapter.add_index(table_name, column_name, options)
    end

    def remove_index(table_name, column_name, **options)
      @adapter.remove_index(table_name, column_name, options)
    end

    # Raw SQL for what the DSL does not cover: triggers, views, PRAGMAs, data
    # fixes. Runs inside the migration's transaction like every other step.
    #   execute "CREATE TRIGGER ..."
    #   execute "UPDATE users SET status = ? WHERE status IS NULL", ['active']
    def execute(sql, params = [])
      @adapter.execute(sql, params)
    end
  end

  class TableDefinition
    attr_reader :columns

    def initialize
      @columns = []
    end

    def field(name, type, **options)
      @columns << { name: name, type: type, **options }
    end

    # created_at / updated_at columns. Dami fills them automatically on
    # create/update when the model declares the same two fields.
    def timestamps
      field(:created_at, :datetime)
      field(:updated_at, :datetime)
    end

    # Shorthand for a foreign-key column: t.references :user -> user_id INTEGER REFERENCES users(id)
    def references(name, **options)
      table = options.delete(:table) || Dami::Inflector.pluralize(name.to_s)
      field(:"#{name}_id", :integer, references: table, **options)
    end
  end
end
