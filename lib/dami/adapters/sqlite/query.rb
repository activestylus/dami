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
    prepared_data = prepare_data(data, model_name)
    columns = prepared_data.keys.join(', ')
    placeholders = (['?'] * prepared_data.keys.size).join(', ')
    sql = "INSERT INTO #{model_name} (#{columns}) VALUES (#{placeholders})"
    execute_prepared(sql, prepared_data.values)
    
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
    @connection_pool.with do |conn|
      cache = conn.instance_variable_get(:@statement_cache)
      stmt = cache[sql] ||= conn.prepare(sql)
      stmt.reset!
      
      converted_params = params.map do |param|
        case param
        when Time
          param.utc.strftime('%Y-%m-%d %H:%M:%S')
        when Date
          param.to_s
        when TrueClass, FalseClass
          param ? 1 : 0
        else
          param
        end
      end
      
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
        join_table = join[:table]
        join_conditions = join[:conditions]
        
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

      if cond_part.is_a?(Array)
        # Handles nested .where { |q| q.where(...).or(...) } blocks
        sub_clause, sub_params = build_where_clause(cond_part)
        clauses << "#{join_word} (#{sub_clause})".strip unless sub_clause.empty?
        params.concat(sub_params)
      elsif cond_part.is_a?(Hash)
        # This is the corrected logic for handling hashes
        hash_clauses = []
        hash_params = []
        cond_part.each do |field, value|
          clause, values = build_condition_part(field, value)
          hash_clauses << clause
          hash_params.concat(values)
        end
        
        unless hash_clauses.empty?
          # Join all conditions from this hash with AND and wrap in parentheses
          full_clause = "(#{hash_clauses.join(' AND ')})"
          clauses << "#{join_word} #{full_clause}".strip
          params.concat(hash_params)
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
    data.transform_values do |value|
      case value
      when Time
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
    return {} unless row.is_a?(Hash)
    model_config = Dami.find_model(model_name) rescue nil
    converted_row = row.each_with_object({}) do |(key, value), hash|
      key = key.to_sym
      field_config = model_config&.dig(:fields, key)
      hash[key] = (field_config && field_config[:type] == :boolean && !value.nil?) ? (value == 1) : value
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