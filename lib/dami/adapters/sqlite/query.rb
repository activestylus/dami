# frozen_string_literal: true
require 'time' 
module SqliteQuery
  OPERATOR_MAP = { gt: '>', lt: '<', gte: '>=', lte: '<=', not: '!='}.freeze
  
  def find_record(model_name, id)
    sql = "SELECT * FROM #{model_name} WHERE id = ? LIMIT 1"
    rows = execute_prepared(sql, [id])
    rows.empty? ? nil : convert_row(rows.first, model_name)
  end
  
def query_records(query)
  sql, params = build_query_sql(query)
  rows = execute_prepared(sql, params)
  rows.map { |row| convert_row(row, query[:model_name], query[:select_columns]) }
end
def query_exists?(query)
  # Build a query that only selects the number 1 and stops after the first row
  query_with_limit = query.merge(select_columns: ['1'], limit: 1)
  sql, params = build_query_sql(query_with_limit)
  
  # If we get any rows back, it exists.
  !execute_prepared(sql, params).empty?
end  
  def insert_record(model_name, data)
    prepared_data = prepare_data(data, model_name)
    columns = prepared_data.keys.join(', ')
    placeholders = (['?'] * prepared_data.keys.size).join(', ')
    sql = "INSERT INTO #{model_name} (#{columns}) VALUES (#{placeholders})"
    execute_prepared(sql, prepared_data.values)
    
    # Get the last inserted ID and return the record
    last_id = last_insert_row_id
    find_record(model_name, last_id)
  end
  
  def insert_many(model_name, records)
    return if records.empty?
    keys = records.first.keys
    columns = keys.join(', ')
    value_placeholder = "(#{(['?'] * keys.size).join(',')})"
    all_placeholders = ([value_placeholder] * records.size).join(', ')
    sql = "INSERT INTO #{model_name} (#{columns}) VALUES #{all_placeholders}"
    params = records.flat_map { |rec| keys.map { |key| rec[key.to_sym] } }
    execute_prepared(sql, params)
  end
  
  def update_records(query, data)
    prepared_data = prepare_data(data, query[:model_name])
    set_clause = prepared_data.keys.map { |k| "#{k} = ?" }.join(', ')
    
    # FIX: Ensure query has safe defaults
    full_query = {
      model_name: query[:model_name],
      conditions: query[:conditions] || [],
      order_by: query[:order_by],
      limit: query[:limit],
      offset: query[:offset]
    }
    
    sql, params = build_query_sql(full_query, "UPDATE #{query[:model_name]} SET #{set_clause}")
    execute_prepared(sql, prepared_data.values + params)
  end
  
  def delete_records(query)
    # FIX: Ensure query has safe defaults
    full_query = {
      model_name: query[:model_name],
      conditions: query[:conditions] || [],
      order_by: query[:order_by],
      limit: query[:limit],
      offset: query[:offset]
    }
    
    sql, params = build_query_sql(full_query, "DELETE FROM #{query[:model_name]}")
    execute_prepared(sql, params)
  end
  
  private
  
def execute_prepared(sql, params = [])
  @connection_pool.with do |conn|
    cache = conn.instance_variable_get(:@statement_cache)
    stmt = cache[sql] ||= conn.prepare(sql)
    stmt.reset!
    
    # Convert parameters for SQLite compatibility
    converted_params = params.map do |param|
      case param
      when Time
        param.utc.strftime('%Y-%m-%d %H:%M:%S')  # Use strftime instead of iso8601
      when Date
        param.to_s
      when TrueClass, FalseClass
        param ? 1 : 0
      else
        param
      end
    end
    
    results = stmt.execute(converted_params)
    
    # Convert to array of hashes
    if results.respond_to?(:to_a)
      results.to_a.map do |row|
        if row.is_a?(Hash)
          row
        else
          # Convert array to hash using column names
          Hash[stmt.columns.zip(row)]
        end
      end
    else
      []
    end
  end
end
  
def build_query_sql(query, base_sql = nil)
  # Use base_sql if provided (for UPDATE/DELETE), otherwise build SELECT
  if base_sql
    sql_parts = [base_sql]
  else
    # Determine the SELECT clause
    select_clause = if query[:select_columns] && !query[:select_columns].empty?
      columns = query[:select_columns].map(&:to_s).join(', ')
      "SELECT #{columns} FROM #{query[:model_name]}"
    else
      "SELECT * FROM #{query[:model_name]}"
    end
    sql_parts = [select_clause]
  end
  
  params = []
  
  # Handle JOINS (only for SELECT queries)
    if !base_sql && query[:joins] && !query[:joins].empty?
    query[:joins].each do |join|
      join_table = join[:table]
      join_conditions = join[:conditions]
      
      # Determine the JOIN type
      join_type_sql = case join[:type]
      when :left then "LEFT OUTER JOIN"
      else "INNER JOIN"
      end
      
      join_clause = "#{join_type_sql} #{join_table} ON "
      conditions = []
      
      join_conditions.each do |left, right|
        conditions << "#{query[:model_name]}.#{left} = #{join_table}.#{right}"
      end
      
      join_clause << conditions.join(' AND ')
      sql_parts << join_clause
    end
  end
  
  # Handle WHERE conditions
  unless query[:conditions].empty?
    where_clauses, where_params = build_where_clause(query[:conditions])
    sql_parts << "WHERE #{where_clauses}" unless where_clauses.empty?
    params.concat(where_params)
  end
  
  # Handle ORDER BY (only for SELECT queries)
  if !base_sql && query[:order_by]
    sql_parts << "ORDER BY #{build_order_clause(query[:order_by])}"
  end
  
  # Handle LIMIT and OFFSET (only for SELECT queries)
  sql_parts << "LIMIT #{query[:limit]}" if !base_sql && query[:limit]
  sql_parts << "OFFSET #{query[:offset]}" if !base_sql && query[:offset]
  
  [sql_parts.join(' '), params]
end
def build_where_clause(conditions)
  clauses = []
  params = []
  
  conditions.each_with_index do |(type, cond_part), index|
    join_word = (index > 0) ? type.to_s.upcase : ""

    if cond_part.is_a?(Array)
      # This is a nested sub-query from a block.
      # Recursively build the sub-clause and wrap it in parentheses.
      sub_clause, sub_params = build_where_clause(cond_part)
      clauses << "#{join_word} (#{sub_clause})".strip unless sub_clause.empty?
      params.concat(sub_params)
    elsif cond_part # Ensure it's not nil
      # This is a simple hash condition.
      cond_part.each do |field, value|
        clause, values = build_condition_part(field, value)
        clauses << "#{join_word} #{clause}".strip
        params.concat(values)
      end
    end
  end
  
  [clauses.join(' '), params]
end

  
  def build_condition_part(field, value)
    case value
    when nil then ["#{field} IS NULL", []]
    when Hash
      sub_clauses = []
      params = []
      value.each do |op, val|
        # Handle special operators first
        case op
        when :not_in
          return ["1=0", []] if val.empty?
          placeholders = (['?'] * val.size).join(',')
          sub_clauses << "#{field} NOT IN (#{placeholders})"
          params.concat(val)
        when :starts_with
          sub_clauses << "#{field} LIKE ?"
          params << "#{val}%"
        when :contains
          sub_clauses << "#{field} LIKE ?"
          params << "%#{val}%"
        when :ends_with
          sub_clauses << "#{field} LIKE ?"
          params << "%#{val}"
        else # Handle standard operators
          sql_op = OPERATOR_MAP[op]
          raise "Unknown operator: #{op}" unless sql_op
          sub_clauses << "#{field} #{sql_op} ?"
          params << val
        end
      end
      ["(#{sub_clauses.join(' AND ')})", params]
    when Array
      return ["1=0", []] if value.empty?
      placeholders = (['?'] * value.size).join(',')
      ["#{field} IN (#{placeholders})", value]
    else ["#{field} = ?", [value]]
    end
  end
def recreate_table_without_column(table, column_to_remove)
  # This is a simplified version - you'd need a full implementation
  temp_table = "#{table}_backup_#{Time.now.to_i}"
  
  # Get current schema
  columns = @adapter.execute("PRAGMA table_info(#{table})")
  keep_columns = columns.reject { |col| col['name'] == column_to_remove.to_s }
  
  # Create new table without the column
  column_defs = keep_columns.map { |col| "#{col['name']} #{col['type']}" }.join(', ')
  @adapter.execute("CREATE TABLE #{temp_table} (#{column_defs})")
  
  # Copy data
  keep_column_names = keep_columns.map { |col| col['name'] }.join(', ')
  @adapter.execute("INSERT INTO #{temp_table} (#{keep_column_names}) SELECT #{keep_column_names} FROM #{table}")
  
  # Replace tables
  @adapter.execute("DROP TABLE #{table}")
  @adapter.execute("ALTER TABLE #{temp_table} RENAME TO #{table}")
end
  def build_order_clause(order_config)
    return nil unless order_config
    
    parts = case order_config
    when Hash
      order_config.map do |field, dir|
        validate_order_fragment(field)
        dir_sql = dir.to_s.upcase
        raise Dami::InvalidCommand, "Invalid order direction: #{dir}" unless %w[ASC DESC].include?(dir_sql)
        "#{field} #{dir_sql}"
      end
    when String, Symbol
      order_config.to_s.split(',').map do |part|
        field, dir = part.strip.split(/\s+/)
        validate_order_fragment(field)
        dir_sql = (dir || 'ASC').upcase
        raise Dami::InvalidCommand, "Invalid order direction: #{dir}" unless %w[ASC DESC].include?(dir_sql)
        "#{field} #{dir_sql}"
      end
    else
      raise Dami::InvalidCommand, "Invalid order argument: #{order_config.inspect}"
    end
    parts.join(', ')
  end
  
  def validate_order_fragment(fragment)
    raise Dami::InvalidCommand, "Invalid character in ORDER BY clause: #{fragment}" unless fragment.to_s.match?(/\A[\w\.]+\z/)
  end
    
def prepare_data(data, model_name)
  data.transform_values do |value|
    case value
    when Time
      # Ruby-compatible time conversion (works across all Ruby versions)
      value.utc.strftime('%Y-%m-%d %H:%M:%S')
    when Date
      value.to_s
    when TrueClass, FalseClass
      value ? 1 : 0
    else
      value
    end
  end
end
def convert_row(row, model_name, select_columns = nil)
  case row
  when Hash
    converted_row = row.transform_keys(&:to_sym)
    
    # Filter columns if select was used
    if select_columns && !select_columns.empty?
      # Extract final column names (handling aliases)
      selected_keys = select_columns.map do |col|
        col_str = col.to_s
        if col_str.include?(' AS ')
          # Extract alias: 'name AS user_name' -> :user_name
          col_str.split(' AS ').last.strip.to_sym
        elsif col_str.include?('.')
          # Extract column from table.column syntax
          col_str.split('.').last.to_sym
        else
          col_str.to_sym
        end
      end
      
      # Keep only the selected columns
      converted_row.select! { |key, _| selected_keys.include?(key) }
    end
    
    converted_row
  else
    {}
  end
end
end