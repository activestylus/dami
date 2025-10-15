# frozen_string_literal: true

module Dami
  module Schema
    # Introspects live Dami.model definitions to build a canonical hash representation.
    class Introspector
      def introspect
        schema = {}
        Dami.instance_variable_get(:@models).each do |model_name, config|
          table_name = model_name.to_s
          schema[table_name] = { columns: {}, indexes: {} }

          # 1. Parse all defined fields
          (config[:fields] || {}).each do |field_name, field_config|
            schema[table_name][:columns][field_name.to_s] = { type: field_config[:type] }
          end

          # 2. Introspect relationships to infer indexes
          (config[:relationships] || {}).each do |type, relations|
            next unless type == :belongs_to
            relations.each_key do |rel_name|
              # A `belongs_to :user` implies a `user_id` column and an index on it.
              # We assume the column is already defined in `fields`.
              # Here, we just add the desired index.
              fk_name = "#{rel_name}_id"
              schema[table_name][:indexes][fk_name] = {}
            end
          end
        end
        schema
      end
    end
  end
end