# File: ./lib/dami/plugins/nested_attributes.rb
module Dami
  module Plugins
    module NestedAttributes
      class Processor
        def initialize(parent_model_name, parent_record, attributes, persistence_options)
          @parent_model_name = parent_model_name
          @parent_record = parent_record
          @attributes = attributes
          @persistence_options = persistence_options
          @parent_model_config = Dami.find_model(parent_model_name)
          @errors = {}
          @to_create = Hash.new { |h, k| h[k] = [] }
          @to_update = Hash.new { |h, k| h[k] = {} }
          @to_delete = Hash.new { |h, k| h[k] = [] }
        end

def validate
  process_nested_attributes(:validate)
  @errors
end

        def process
          process_nested_attributes(:save)
          execute_operations
        end

        private

        def process_nested_attributes(mode)
          nested_configs = @parent_model_config[:nests] || {}
          
          nested_configs.keys.each do |attr_key|
            next unless @attributes.key?(attr_key)
            
            config = nested_configs[attr_key]
            records_data = @attributes[attr_key]
            process_nested_records(attr_key, config, records_data, mode)
          end
        end

def process_nested_records(attr_key, config, records_data, mode)
  assoc_name = config[:association_name]
  child_rel = @parent_model_config.dig(:relationships, :has_many, assoc_name)
  raise "Undefined has_many association '#{assoc_name}' for nested attributes" unless child_rel
  
  child_model_name = child_rel[:model] || assoc_name
  foreign_key = child_rel[:foreign_key] || "#{@parent_model_name.to_s.singularize}_id".to_sym
  
  # Preserve the original keys when processing hashes
  if records_data.is_a?(Hash)
    records_data.each do |original_key, child_attrs|
      # Use the original string key for error indexing
      process_single_record(attr_key, original_key, child_model_name, foreign_key, config, child_attrs, mode)
    end
  else
    records_array = Array(records_data)
    records_array.each_with_index do |child_attrs, index|
      process_single_record(attr_key, index.to_s, child_model_name, foreign_key, config, child_attrs, mode)
    end
  end
end

def process_single_record(attr_key, index_key, child_model_name, foreign_key, config, child_attrs, mode)
  child_attrs = child_attrs.transform_keys(&:to_sym)
  id = child_attrs[:id]
  destroy = ['true', '1', true].include?(child_attrs[:_destroy])
  grandchild_attrs = extract_grandchild_attributes(child_model_name, child_attrs)
  if mode == :validate || !destroy
    validate_record(child_model_name, child_attrs, grandchild_attrs, attr_key, index_key, id)
  end

  if mode == :save
    if destroy && config[:allow_destroy] && id
      @to_delete[child_model_name] << id
    elsif !destroy
      if id
        @to_update[child_model_name][id] = { 
          attrs: child_attrs, 
          grandchildren: grandchild_attrs 
        }
      else
        child_attrs[foreign_key] = @parent_record[:id]
        @to_create[child_model_name] << { 
          attrs: child_attrs, 
          grandchildren: grandchild_attrs 
        }
      end
    end
  end
end

def validate_record(child_model_name, child_attrs, grandchild_attrs, attr_key, index_key, id)
  child_errors = {}
  
  begin
  
    Dami.validate!(child_model_name, child_attrs, on: id ? :update : :create)
  rescue Dami::ValidationError => e
  
    child_errors.merge!(e.errors)
  end

  # Validate grandchildren recursively
  if grandchild_attrs.any?
  
    grandchild_processor = self.class.new(child_model_name, nil, grandchild_attrs, @persistence_options)
    grandchild_errors = grandchild_processor.validate
  
    child_errors.merge!(grandchild_errors) unless grandchild_errors.empty?
  end

  add_error(attr_key, index_key, child_errors) unless child_errors.empty?
  
end

        def extract_grandchild_attributes(model_name, attributes)
          nested_keys = (Dami.find_model(model_name)[:nests] || {}).keys
          nested_keys.each_with_object({}) do |key, hash|
            hash[key] = attributes.delete(key) if attributes.key?(key)
          end
        end

        def add_error(attr_key, index, error_hash)
          (@errors[attr_key] ||= {})[index] = error_hash
        end

def execute_operations
  # We need to execute in this order: deletes, then updates, then creates
  execute_deletes
  execute_updates  
  execute_creates
end


def execute_deletes
  @to_delete.each do |model, ids|
    ids.each do |id|
      before = Dami.db(model).find(id)
      result = Dami.db(model).where(id: id).delete
      after = Dami.db(model).find(id)
    end
  end
end

        def execute_updates
          @to_update.each do |model, updates|
            updates.each do |id, data|
              Dami.db(model).where(id: id).update(data[:attrs], **@persistence_options)
              if data[:grandchildren].any?
                child_record = Dami.db(model).find(id)
                processor = self.class.new(model, child_record, data[:grandchildren], @persistence_options)
                processor.process
              end
            end
          end
        end

def execute_creates
  @to_create.each do |model, records|
    records.each do |data|
      created_child = Dami.db(model).create(data[:attrs], **@persistence_options)
      if data[:grandchildren].any?
        processor = self.class.new(model, created_child, data[:grandchildren], @persistence_options)
        processor.process
      else
        #
      end
    end
  end
end
      end
    end
  end
end