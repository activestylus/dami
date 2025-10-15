# frozen_string_literal: true
module Dami
  module Query
    module Persistence
      def create(attrs = {}, **options, &block)
        attributes = attrs.merge(options)
        if block_given?
          draft = ::Dami::Draft.new(original: nil, data: attributes)
          yield(draft)
          raise ::Dami::ValidationError.new("Validation failed", draft.errors) unless draft.valid?
          attributes = draft.data
        end
        permit = attributes.delete(:permit) || []
        protect = attributes.key?(:protect) ? attributes.delete(:protect) : true
        model_config = Dami.find_model(@model_name)
        known_fields = (model_config[:fields] || {}).keys + (model_config[:virtual_fields] || {}).keys + [:id]
        unknown = attributes.keys - known_fields
        raise Dami::UnknownFieldsError.new("Unknown fields: #{unknown.join(', ')}", unknown) unless unknown.empty?
        Dami.validate!(@model_name, attributes, on: :create)
        filtered_attrs = Dami.filter_input!(@model_name, attributes, permit: permit, protect: protect)
        virtual_fields = (model_config[:virtual_fields] || {}).keys
        db_attrs = filtered_attrs.reject { |k, _| virtual_fields.include?(k) }
        return if db_attrs.empty?
        record = adapter.insert_record(@model_name, db_attrs)
        ::Dami::RecordProxy.new(@model_name, record)
      end
      def create_many(records)
        return if records.empty?
        adapter.insert_many(@model_name, records)
      end
      def update(attrs = {}, **options, &block)
        attributes = attrs.merge(options)
        original_record = self.to_a.first
        if block_given?
          return nil unless original_record
          draft = ::Dami::Draft.new(original: original_record.to_h, data: attributes)
          yield(draft)
          return nil unless draft.valid?
          attributes = draft.data
        end
        return find(original_record[:id]) if attributes.empty? && original_record
        permit = attributes.delete(:permit) || []
        protect = attributes.key?(:protect) ? attributes.delete(:protect) : true
        model_config = Dami.find_model(@model_name)
        known_fields = (model_config[:fields] || {}).keys + (model_config[:virtual_fields] || {}).keys + [:id]
        unknown = attributes.keys - known_fields
        raise Dami::UnknownFieldsError.new("Unknown fields: #{unknown.join(', ')}", unknown) unless unknown.empty?
        Dami.validate!(@model_name, attributes, on: :update)
        filtered_attrs = Dami.filter_input!(@model_name, attributes, permit: permit, protect: protect)
        virtual_fields = (model_config[:virtual_fields] || {}).keys
        db_attrs = filtered_attrs.reject { |k, _| virtual_fields.include?(k) }
        return find(original_record[:id]) if db_attrs.empty?
        adapter.update_records(build_query_structure, db_attrs)
        find(original_record[:id]) if original_record
      end
      def delete
        adapter.delete_records(build_query_structure)
      end
    end
  end
end