# frozen_string_literal: true

module Dami
  module Schema
    class Dumper
      def initialize(adapter)
        @adapter = adapter
      end

      # The main public method. It inspects the database and returns
      # a string containing the full schema definition.
      def dump
        output = []
        output << "Dami.define_schema do\n"

        tables = @adapter.tables
        tables.each do |table_name|
          next if table_name == 'schema_migrations' # Skip the internal migrations table

          output << dump_table(table_name)
        end

        tables.each do |table_name|
          output << dump_indexes(table_name)
        end

        output << "end\n"
        output.join("\n")
      end

      private

      def dump_table(table_name)
        columns = @adapter.columns(table_name)
        return "" if columns.empty?

        parts = []
        parts << "  create_table \"#{table_name}\" do |t|"
        columns.each do |column|
          # We skip the 'id' column as it's created by default.
          next if column[:name] == "id"
          parts << "    t.field \"#{column[:name]}\", :#{column[:type]}"
        end
        parts << "  end"
        parts.join("\n")
      end

      def dump_indexes(table_name)
        indexes = @adapter.indexes(table_name)
        return "" if indexes.empty?

        parts = []
        indexes.each do |index|
          parts << "  add_index \"#{index[:table]}\", \"#{index[:column]}\""
        end
        parts.join("\n")
      end
    end
  end
end