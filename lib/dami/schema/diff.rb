# frozen_string_literal: true

module Dami
  module Schema
    class Diff
      def initialize(old_schema, new_schema)
        @old_schema = old_schema
        @new_schema = new_schema
        @up_commands = []
        @down_commands = []
      end

      # The main public method that computes the differences.
      def diff
        find_added_tables
        find_removed_tables
        find_changed_tables

        { up: @up_commands, down: @down_commands }
      end

      private

      def find_added_tables
        (@new_schema.keys - @old_schema.keys).each do |table_name|
          @up_commands << { command: :create_table, name: table_name, columns: @new_schema[table_name][:columns] }
          @down_commands.unshift({ command: :drop_table, name: table_name })
          # Also add any indexes for the new table
          (@new_schema[table_name][:indexes] || {}).each do |column_name, _|
            @up_commands << { command: :add_index, table: table_name, column: column_name }
          end
        end
      end

      def find_removed_tables
        (@old_schema.keys - @new_schema.keys).each do |table_name|
          @up_commands << { command: :drop_table, name: table_name }
          @down_commands.unshift({ command: :create_table, name: table_name, columns: @old_schema[table_name][:columns] })
          # Restore indexes for the dropped table on rollback
          (@old_schema[table_name][:indexes] || {}).each do |column_name, _|
            @down_commands.unshift({ command: :add_index, table: table_name, column: column_name })
          end
        end
      end
      
      def find_changed_tables
        (@old_schema.keys & @new_schema.keys).each do |table_name|
          diff_columns(table_name)
          diff_indexes(table_name)
        end
      end

      def diff_columns(table_name)
        old_cols = @old_schema[table_name][:columns]
        new_cols = @new_schema[table_name][:columns]
        
        (new_cols.keys - old_cols.keys).each do |col_name|
          @up_commands << { command: :add_column, table: table_name, name: col_name, type: new_cols[col_name][:type] }
          @down_commands.unshift({ command: :remove_column, table: table_name, name: col_name })
        end
        
        (old_cols.keys - new_cols.keys).each do |col_name|
          @up_commands << { command: :remove_column, table: table_name, name: col_name }
          @down_commands.unshift({ command: :add_column, table: table_name, name: col_name, type: old_cols[col_name][:type] })
        end
      end

      def diff_indexes(table_name)
        old_indexes = @old_schema[table_name][:indexes] || {}
        new_indexes = @new_schema[table_name][:indexes] || {}

        (new_indexes.keys - old_indexes.keys).each do |col_name|
          @up_commands << { command: :add_index, table: table_name, column: col_name }
          @down_commands.unshift({ command: :remove_index, table: table_name, column: col_name })
        end

        (old_indexes.keys - new_indexes.keys).each do |col_name|
          @up_commands << { command: :remove_index, table: table_name, column: col_name }
          @down_commands.unshift({ command: :add_index, table: table_name, column: col_name })
        end
      end
    end
  end
end