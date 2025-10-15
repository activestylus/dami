# frozen_string_literal: true
require_relative 'enumerable'
require_relative 'persistence'

module Dami
  module Query
    class Builder
      include ::Enumerable
      include Dami::Query::Enumerable
      include Dami::Query::Persistence

      def initialize(model_name, db_name: :default, conditions: [], order_by: nil, limit: nil, offset: nil, preload: [], select_columns: nil, joins: [])
        @model_name = model_name
        @db_name = db_name
        @conditions = conditions
        @order_by = order_by
        @limit = limit
        @offset = offset
        @preload = preload
        @select_columns = select_columns
        @joins = joins
      end

      def where(conds = nil, &block)
        if block
          sub_query = self.class.new(@model_name)
          block.call(sub_query)
          clone_with(conditions: @conditions + [[:and, sub_query.instance_variable_get(:@conditions)]])
        else
          clone_with(conditions: @conditions + [[:and, conds]])
        end
      end

      def or(conds = nil, &block)
        if block
          sub_query = self.class.new(@model_name, db_name: @db_name)
          block.call(sub_query)
          clone_with(conditions: @conditions + [[:or, sub_query.instance_variable_get(:@conditions)]])
        else
          clone_with(conditions: @conditions + [[:or, conds]])
        end
      end
      
      def join(table, conditions)
        join_clause = { type: :inner, table: table, conditions: conditions }
        clone_with(joins: @joins + [join_clause])
      end

      def left_join(table, conditions)
        join_clause = { type: :left, table: table, conditions: conditions }
        clone_with(joins: @joins + [join_clause])
      end

      def select(*columns)
        clone_with(select_columns: columns)
      end
      
      def order(field)
        clone_with(order_by: field)
      end
      
      def limit(count)
        clone_with(limit: count.to_i)
      end
      
      def offset(count)
        clone_with(offset: count.to_i)
      end
      
      def preload(*relations)
        clone_with(preload: @preload + relations)
      end

      private
      
      def reverse_order_query
        return order(id: :desc) unless @order_by

        reversed_order = case @order_by
        when Hash
          @order_by.transform_values { |dir| dir == :asc ? :desc : :asc }
        when String, Symbol
          parts = @order_by.to_s.split(',').map do |part|
            field, dir = part.strip.split(/\s+/)
            new_dir = (dir&.upcase == 'DESC') ? 'ASC' : 'DESC'
            "#{field} #{new_dir}"
          end
          parts.join(', ')
        else
          { id: :desc }
        end

        clone_with(order_by: reversed_order)
      end

      def adapter
        Dami.database(@db_name)
      end
      
      def clone_with(**new_opts)
        self.class.new(
          @model_name, 
          db_name: @db_name, 
          conditions: @conditions, 
          order_by: @order_by, 
          limit: @limit, 
          offset: @offset, 
          preload: @preload,
          select_columns: @select_columns,
          joins: @joins,
          **new_opts
        )
      end
      
      def build_query_structure
        { 
          model_name: @model_name, 
          conditions: @conditions, 
          order_by: @order_by, 
          limit: @limit, 
          offset: @offset,
          select_columns: @select_columns,
          joins: @joins,
          preload: @preload
        }
      end
    end
  end
end