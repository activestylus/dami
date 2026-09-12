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

  def count_records(query)
    # Build a query that only selects the count
    count_query = query.merge(
      select_columns: ['COUNT(*) as count'],
      order_by: nil, # Ordering is irrelevant for a count
      limit: nil,
      offset: nil
    )
    sql, params = build_query_sql(count_query)
    result = get_first_row(sql, params)
    # The result will be a hash like {'count' => 123}, so we extract the value.
    result ? result['count'] : 0
  end

  def query_exists?(query)
    query_with_limit = query.merge(select_columns: ['1'], limit: 1)
    sql, params = build_query_sql(query_with_limit)
    !execute_prepared(sql, params).empty?
  end

  def insert_record(model_name, data)
    prepared_data = prepare_data(stamp_timestamps(data, model_name, :create), model_name)
    columns = prepared_data.keys.join(', ')
    placeholders = (['?'] * prepared_data.keys.size).join(', ')
    sql = "INSERT INTO #{model_name} (#{columns}) VALUES (#{placeholders})"
    transaction do
      execute_prepared(sql, prepared_data.values)
      find_record(model_name, last_insert_row_id)
    end
  end
  def insert_many(table, records)
    return [] if records.empty?
    records = records.map { |r| prepare_data(stamp_timestamps(r, table, :create), table) }
    columns = records.first.keys
    columns.each { |c| validate_identifier(c) }
    placeholders = "(#{columns.map { '?' }.join(', ')})"
    sql = "INSERT INTO #{table} (#{columns.join(', ')}) VALUES #{records.map { placeholders }.join(', ')}"
    values = records.flat_map { |record| columns.map { |col| record[col] } }
    # Both statements must run on the same connection, or last_insert_row_id
    # can come from a different pooled connection. transaction guarantees that.
    transaction do
      execute(sql, values)
      last_id = last_insert_row_id
      count = records.size
      (last_id - count + 1..last_id).to_a
    end
  end
  
  def update_records(query, data)
    prepared_data = prepare_data(stamp_timestamps(data, query[:model_name], :update), query[:model_name])
    set_clause = prepared_data.keys.map { |k| "#{k} = ?" }.join(', ')
    
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
    converted_params = convert_params(params)
    conn = Thread.current[:dami_sqlite_connection]
    return run_prepared(conn, sql, converted_params) if conn
    @connection_pool.with { |c| run_prepared(c, sql, converted_params) }
  rescue SQLite3::Exception => e
    handle_sqlite_error(e, sql: sql)
  end

  def run_prepared(conn, sql, converted_params)
    begin
      cache = conn.instance_variable_get(:@statement_cache)
      stmt = cache[sql] ||= conn.prepare(sql)
      stmt.reset!
      
      results = stmt.execute(converted_params)
      
      if results.respond_to?(:to_a)
        results.to_a.map do |row|
          if row.is_a?(Hash)
            row
          else
            Hash[stmt.columns.zip(row)]
          end
        end
      else
        []
      end
    end
  end
  
  def build_query_sql(query, base_sql = nil)
    if base_sql
      sql_parts = [base_sql]
    else
      select_clause = if query[:select_columns] && !query[:select_columns].empty?
        columns = query[:select_columns].map(&:to_s).join(', ')
        "SELECT #{columns} FROM #{query[:model_name]}"
      else
        "SELECT * FROM #{query[:model_name]}"
      end
      sql_parts = [select_clause]
    end
    
    params = []
    
    if !base_sql && query[:joins] && !query[:joins].empty?
      query[:joins].each do |join|
        join_table = validate_identifier(join[:table])
        join_conditions = join[:conditions]
        join_conditions.each { |l, r| validate_identifier(l); validate_identifier(r) }
        
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
    
    unless query[:conditions].empty?
      where_clauses, where_params = build_where_clause(query[:conditions])
      sql_parts << "WHERE #{where_clauses}" unless where_clauses.empty?
      params.concat(where_params)
    end
    
    if !base_sql && query[:order_by]
      sql_parts << "ORDER BY #{build_order_clause(query[:order_by])}"
    end
    
    sql_parts << "LIMIT #{query[:limit]}" if !base_sql && query[:limit]
    sql_parts << "OFFSET #{query[:offset]}" if !base_sql && query[:offset]
    
    [sql_parts.join(' '), params]
  end

def build_where_clause(conditions)
    clauses = []
    params = []
    
    conditions.each_with_index do |(type, cond_part), index|
      join_word = (index > 0) ? type.to_s.upcase : ""

      if cond_part.is_a?(Array) && cond_part.first.is_a?(String) && cond_part.first.include?('?')
        # This is a raw SQL fragment like ['age > ?', 30]
        clauses << "#{join_word} #{cond_part.first}".strip
        params.concat(cond_part[1..-1])
      elsif cond_part.is_a?(Array)
        # This is a nested block of conditions
        sub_clause, sub_params = build_where_clause(cond_part)
        clauses << "#{join_word} (#{sub_clause})".strip unless sub_clause.empty?
        params.concat(sub_params)
      elsif cond_part.is_a?(Hash)
        # This is a hash of conditions
        hash_clauses = []
        hash_params = []
        cond_part.each do |field, value|
          clause, values = build_condition_part(field, value)
          hash_clauses << clause
          hash_params.concat(values)
        end
        
        unless hash_clauses.empty?
          full_clause = "(#{hash_clauses.join(' AND ')})"
          clauses << "#{join_word} #{full_clause}".strip
          params.concat(hash_params)
        end
      end
    end
    
    [clauses.join(' '), params]
  end

def build_condition_part(field, value)
    validate_identifier(field)
    case value
    when nil then ["#{field} IS NULL", []]
    when Hash
      sub_clauses = []
      params = []
      value.each do |op, val|
        # FIX #2: Handle `{ not: nil }` to generate `IS NOT NULL`
        if op == :not && val.nil?
          sub_clauses << "#{field} IS NOT NULL"
          next
        end

        case op
        when :not_in
          # FIX #1: Handle `{ not_in: [] }` to generate `1=1` (true)
          return ["1=1", []] if val.empty?
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
        else
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
    model_config = Dami.find_model(model_name) rescue nil
    data.each_with_object({}) do |(key, value), out|
      validate_identifier(key)
      field_type = model_config&.dig(:fields, key.to_sym, :type)
      out[key] = if field_type == :json
        value.nil? ? nil : JSON.generate(value)
      else
        convert_value(value)
      end
    end
  end

  # Fills created_at / updated_at when the model declares them and the caller
  # did not supply a value. Operation is :create or :update.
  def stamp_timestamps(data, model_name, operation)
    model_config = Dami.find_model(model_name) rescue nil
    return data unless model_config
    fields = model_config[:fields] || {}
    now = Time.now.utc
    data = data.dup
    if operation == :create && fields.key?(:created_at) && !data.key?(:created_at)
      data[:created_at] = now
    end
    if fields.key?(:updated_at) && !data.key?(:updated_at)
      data[:updated_at] = now
    end
    data
  end

  # Column and table names are interpolated into SQL, so they must be plain
  # identifiers. Values are always bound; this guards the names.
  def validate_identifier(name)
    str = name.to_s
    return str if str.match?(/\A[A-Za-z_][\w.]*\z/)
    raise Dami::InvalidIdentifier, "Invalid SQL identifier: #{str.inspect}"
  end

  def convert_row(row, model_name, select_columns = nil)
    return {} unless row.is_a?(Hash)
    model_config = Dami.find_model(model_name) rescue nil
    converted_row = row.each_with_object({}) do |(key, value), hash|
      key = key.to_sym
      field_type = model_config&.dig(:fields, key, :type)
      hash[key] = case field_type
                  when :boolean then value.nil? ? nil : (value == 1 || value == true)
                  when :json then value.nil? ? nil : (JSON.parse(value) rescue value)
                  else value
                  end
    end
    if select_columns && !select_columns.empty?
      selected_keys = select_columns.map do |col|
        col_str = col.to_s
        (col_str.include?(' AS ') ? col_str.split(' AS ').last.strip : (col_str.include?('.') ? col_str.split('.').last : col_str)).to_sym
      end
      converted_row.select! { |key, _| selected_keys.include?(key) }
    end
    converted_row
  end
end