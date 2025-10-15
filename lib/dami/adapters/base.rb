# frozen_string_literal: true
module Dami
  module Adapters
    class Base
      def initialize(config)
        @config = config
        @connection = nil
      end
      def [](model_name)
        Dami.db(model_name)
      end
      def ensure_schema_migrations_table
        raise NotImplementedError
      end

      def table_exists?(table_name)
        raise NotImplementedError
      end
      def connect; raise NotImplementedError; end
      def add_index(table, column, options = {}); raise NotImplementedError; end
      def remove_index(table, column, options = {}); raise NotImplementedError; end
      def tables; raise NotImplementedError; end
      def columns(table_name); raise NotImplementedError; end
      def indexes(table_name); raise NotImplementedError; end
      def execute(sql, params = []); raise NotImplementedError; end
      def get_first_row(sql, params = []); raise NotImplementedError; end
      def last_insert_row_id; raise NotImplementedError; end
      def find_record(model_name, id); raise NotImplementedError; end
      def query_records(query); raise NotImplementedError; end
      def insert_record(model_name, data); raise NotImplementedError; end
      def insert_many(model_name, records); raise NotImplementedError; end
      def update_records(query, data); raise NotImplementedError; end
      def delete_records(query); raise NotImplementedError; end
      def transaction(&block); raise NotImplementedError; end
      def fetch_association(record, association_name); raise NotImplementedError; end
      def preload_associations(proxies, relations); raise NotImplementedError; end
    end
  end
end