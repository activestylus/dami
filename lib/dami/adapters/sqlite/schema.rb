# frozen_string_literal: true
module SqliteSchema
# In lib/dami/adapters/sqlite/schema.rb or connection.rb
def ensure_schema_migrations_table
  # Check if table exists
  table_check = execute("SELECT name FROM sqlite_master WHERE type='table' AND name='schema_migrations'")
  return unless table_check.empty?
  
  # Create the table
  execute <<-SQL
    CREATE TABLE schema_migrations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      version VARCHAR(255) NOT NULL UNIQUE
    )
  SQL
end

def table_exists?(table_name)
  !execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", [table_name.to_s]).empty?
end

def column_exists?(table_name, column_name)
  return false unless table_exists?(table_name)
  columns = execute("PRAGMA table_info(#{table_name})")
  columns.any? { |col| col['name'] == column_name.to_s }
end
  def execute_schema_operations(ops)
    ops.each do |op|
      case op[:type]
      when :create_table then create_table(op[:name], op[:columns])
      when :drop_table then drop_table(op[:name])
      when :add_column then add_column(op[:table], op[:name], op[:column_type], **op[:options])
      end
    end
  end
  def create_table(name, columns)
    column_defs = columns.map { |c| column_definition(c) }.join(", ")
    execute("CREATE TABLE #{name} (#{column_defs})")
  end
  def drop_table(name)
    execute("DROP TABLE IF EXISTS #{name}")
  end
  def add_column(table, name, type, **options)
    execute("ALTER TABLE #{table} ADD COLUMN #{column_definition({name: name, type: type, **options})}")
  end

  def column_exists?(table, column)
    columns(table).any? { |col| col[:name] == column.to_s }
  end
  def columns(table)
    execute("PRAGMA table_info(#{table})").map { |row| { name: row['name'], type: sqlite_to_ruby_type(row['type']) } }
  end
  def add_index(table, column, options = {})
    index_name = "index_#{table}_on_#{column}"
    execute("CREATE INDEX #{index_name} ON #{table} (#{column})")
  end

  def remove_index(table, column, options = {})
    index_name = "index_#{table}_on_#{column}"
    execute("DROP INDEX IF EXISTS #{index_name}")
  end
  def tables
    # Query the sqlite_master table for all user-defined table names.
    execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
      .map { |row| row["name"] }
  end

  def columns(table_name)
    # Use PRAGMA to get column info and map it to a friendly format.
    execute("PRAGMA table_info(#{table_name})").map do |col|
      { name: col['name'], type: sqlite_to_dami_type(col['type']) }
    end
  end

  def indexes(table_name)
    # Use PRAGMA to get index info.
    # We filter out primary key and implicit indexes.
    execute("PRAGMA index_list('#{table_name}')")
      .select { |index| index['origin'] == 'c' } # 'c' means created by a CREATE INDEX statement
      .map do |index|
        # For each index, find out which column it's on.
        index_info = execute("PRAGMA index_info('#{index['name']}')").first
        { table: table_name, column: index_info['name'] } if index_info
      end
      .compact
  end
  def column_definition(col)
    parts = ["#{col[:name]} #{map_type(col[:type])}"]
    parts << "PRIMARY KEY AUTOINCREMENT" if col[:type] == :primary_key
    parts.join(' ')
  end
  def map_type(type)
    case type.to_sym
    when :primary_key, :integer, :boolean then 'INTEGER'
    when :string, :text, :json then 'TEXT'
    else 'TEXT'
    end
  end
  def sqlite_to_ruby_type(type)
    case type.upcase
    when 'INTEGER' then :integer
    when 'TEXT' then :string
    else :string
    end
  end


  private

  # New private helper to map SQLite types back to Dami's DSL types.
  def sqlite_to_dami_type(db_type)
    case db_type.upcase
    when /INT/    then :integer
    when /CHAR|TEXT/ then :string
    when /REAL|DOUBLE|FLOAT/ then :float
    when /DECIMAL/ then :decimal
    when /BOOL/   then :boolean
    when /DATETIME/ then :datetime
    else :string # Default fallback
    end
  end
end