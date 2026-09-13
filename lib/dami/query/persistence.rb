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
        prepared = _prepare_persistence(attributes, :create)
        return nil if prepared[:db_parent_attrs].empty? && prepared[:nested_attributes].empty?
        parent_proxy = nil
        adapter.transaction do
          parent_record_hash = adapter.insert_record(@model_name, prepared[:db_parent_attrs])
          parent_proxy = ::Dami::RecordProxy.new(@model_name, parent_record_hash)
          if prepared[:nested_attributes].any?
            processor = ::Dami::Plugins::NestedAttributes::Processor.new(@model_name, parent_proxy, prepared[:nested_attributes], prepared[:persistence_opts])
            processor.process
          end
        end
        parent_proxy ? find(parent_proxy[:id]) : nil
      end
      def update(attrs = {}, **options, &block)
        original_record = self.first
        return nil unless original_record
        attributes = attrs.merge(options)
        if block_given?
          draft = ::Dami::Draft.new(original: original_record.to_h, data: attributes)
          yield(draft)
          return nil unless draft.valid?
          attributes = draft.data
        end
        return original_record if attributes.empty?
        prepared = _prepare_persistence(attributes, :update, original_record)
        adapter.transaction do
          adapter.update_records(build_query_structure, prepared[:db_parent_attrs]) if prepared[:db_parent_attrs].any?
          if prepared[:nested_attributes].any?
            processor = ::Dami::Plugins::NestedAttributes::Processor.new(@model_name, original_record, prepared[:nested_attributes], prepared[:persistence_opts])
            processor.process
          end
        end
        find(original_record[:id])
      end
# File: lib/dami/query/persistence.rb

def create_many(records, permit: [], protect: true)
  raise ArgumentError, "create_many requires an array of hashes" unless records.is_a?(Array)
  return [] if records.empty?
  
  # Phase 1: Validate and prepare ALL records first
  prepared_records = []
  all_errors = {}
  
  records.each_with_index do |attrs, index|
    begin
      attributes = attrs.merge(permit: permit, protect: protect)
      prepared = _prepare_persistence(attributes, :create)
      
      if prepared[:nested_attributes].any?
        raise ArgumentError, "create_many does not support nested attributes. Use create() for complex records."
      end
      
      if prepared[:db_parent_attrs].empty?
        raise ArgumentError, "Record #{index} has no valid attributes after filtering"
      end
      
      prepared_records << prepared[:db_parent_attrs]
    rescue Dami::ValidationError => e
      all_errors[index] = e.errors
    rescue Dami::ProtectionError, Dami::UnknownFieldsError => e
      raise e
    end
  end
  
  # If ANY validations failed, raise with collected errors
  unless all_errors.empty?
    message = "Validation failed for #{all_errors.size} record(s): " + 
              all_errors.map { |idx, errs| "Record #{idx}: #{errs}" }.join("; ")
    raise Dami::ValidationError.new(message, all_errors)
  end
  
  # Phase 2: Bulk insert in transaction
  result_ids = adapter.transaction do
    adapter.insert_many(@model_name, prepared_records)
  end
  
  # Phase 3: Return wrapped records
  result_ids.map.with_index do |id, index|
    record_hash = prepared_records[index].merge(id: id)
    ::Dami::RecordProxy.new(@model_name, record_hash)
  end
end
      def delete
        adapter.delete_records(build_query_structure)
      end
      private

def _prepare_persistence(attributes, operation, parent_record = nil)
  persistence_opts = {
    permit: attributes.delete(:permit) || [],
    protect: attributes.key?(:protect) ? attributes.delete(:protect) : true
  }
  model_config = Dami.find_model(@model_name)
  parent_attributes = attributes.dup
  nested_attributes = (model_config[:nests] || {}).keys.each_with_object({}) do |key, hash|
    hash[key] = parent_attributes.delete(key) if parent_attributes.key?(key)
  end
  all_errors = {}
  if nested_attributes.any?
    processor = ::Dami::Plugins::NestedAttributes::Processor.new(@model_name, parent_record, nested_attributes, persistence_opts)
    nested_errors = processor.validate
    nested_errors.each do |nested_attr_key, nested_error_value|
      all_errors[nested_attr_key] = nested_error_value
    end
  end
  begin
    Dami.validate!(@model_name, parent_attributes, on: operation)
  rescue Dami::ValidationError => e
    all_errors.merge!(e.errors)
  end
  raise Dami::ValidationError.new("Validation failed", all_errors) unless all_errors.empty?
  filtered_parent_attrs = Dami.filter_input!(@model_name, parent_attributes, **persistence_opts)
  db_parent_attrs = filtered_parent_attrs.reject { |k, _| (model_config[:virtual_fields] || {}).key?(k) }
  { db_parent_attrs: db_parent_attrs, nested_attributes: nested_attributes, persistence_opts: persistence_opts }
end
    end
  end
end
