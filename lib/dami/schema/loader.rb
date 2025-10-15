# File: ./lib/dami/schema/loader.rb

# frozen_string_literal: true

module Dami
  module Schema
    # Parses a db/schema.rb file into a canonical hash representation.
    class Loader
      attr_reader :schema

      def initialize
        @schema = {}
      end

      def load_from_path(path)
        return unless File.exist?(path)
        
        # THE FIX: Capture `self` (the loader instance) into a variable.
        loader_instance = self
        
        # Now, the monkey-patched method uses the captured variable, ensuring
        # the block is always evaluated in the context of the correct loader instance.
        Dami.define_singleton_method(:define_schema) { |&block| loader_instance.instance_eval(&block) }
        
        load(path)
      ensure
        # Always restore the original method to avoid side effects.
        Dami.define_singleton_method(:define_schema) { |_| }
      end

      private

      # --- DSL Methods available inside db/schema.rb ---

      def create_table(name, &block)
        @schema[name] ||= { columns: {}, indexes: {} }
        proxy = TableProxy.new(@schema[name][:columns])
        yield(proxy)
      end

      def add_index(table_name, column_name, **options)
        @schema[table_name] ||= { columns: {}, indexes: {} }
        @schema[table_name][:indexes][column_name] = options
      end

      # A simple proxy to handle the `t.field` calls inside `create_table`
      class TableProxy
        def initialize(columns_hash)
          @columns = columns_hash
        end

        def field(name, type, **options)
          @columns[name] = { type: type }.merge(options)
        end
      end
    end
  end
end