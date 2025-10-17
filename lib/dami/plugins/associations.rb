# frozen_string_literal: true
module Dami
  module Plugins
    module Associations
      # Central cache for the dynamically generated association modules (Flyweights).
      @association_modules = {}

      # Clears the module cache. Used primarily for testing to ensure a clean state.
      def self.clear_cache!
        @association_modules.clear
      end

      # Defines class-level methods that will be extended onto the main Dami module.
      # This provides the central mechanism for creating and caching the association modules.
      module ClassMethods
        # Direct accessor for the plugin's module cache.
        def association_module_cache
          Associations.instance_variable_get(:@association_modules)
        end

        # Retrieves a cached association module for a given model name.
        # If the module doesn't exist, it creates it once and caches it.
        def association_module_for(model_name)
          association_module_cache[model_name] ||= create_association_module(model_name)
        end

        private

        # Creates a new shared module for a specific model type. This module
        # contains all the association accessor methods (e.g., #user, #posts).
        def create_association_module(model_name)
          mod = Module.new
          model_config = Dami.find_model(model_name) rescue nil
          return mod unless model_config && (rels = model_config[:relationships])

          rels.each do |_type, rel_config|
            rel_config.each do |name, _options|
              # Handle different ways associations can be defined (e.g., polymorphic).
              actual_name = name.is_a?(Hash) ? name.keys.first : name
              
              # Define the accessor method within the shared module.
              mod.define_method(actual_name) do
                # This block runs in the context of a RecordProxy instance.
                # It first checks for a preloaded value, otherwise it lazy-loads.
                @preloaded[actual_name] ||= fetch_association(actual_name)
              end
            end
          end
          mod
        end
      end

      # Contains instance-level methods for RecordProxy objects, primarily the
      # logic for lazy-loading associations when they are not preloaded.
      module RecordProxyMethods
        # This initialize is included but ultimately superseded by the prepended version
        # in self.apply. It's kept to match the provided source structure.
        def initialize(model_name, record, preloaded = {})
          super
          extend Dami.association_module_for(@model_name)
        end

        private

        # Fetches a single association on-demand (lazy-loading). This is the
        # fallback when an association was not eager-loaded via .preload.
        def fetch_association(assoc_name)
          model_config = Dami.find_model(@model_name)
          type, config = find_association_config(model_config, assoc_name)
          return fetch_has_many_through(config) if config[:through]

          case type
          when :belongs_to
            return fetch_polymorphic_belongs_to(config) if config[:polymorphic]
            fk = config[:foreign_key] || "#{assoc_name}_id".to_sym
            return nil unless (id = @record[fk])
            model_name = config[:model] || Dami::Inflector.pluralize(assoc_name.to_s).to_sym
            ::Dami.db(model_name).find(id)
          when :has_many
            _fk, model_name = association_keys(type, assoc_name, config)
            query = ::Dami.db(model_name).where(association_keys(type, assoc_name, config)[0] => @record[:id])
            query = query.where("#{config[:as]}_type".to_sym => Dami::Inflector.singularize(@model_name.to_s).capitalize) if config[:as]
            query
          when :has_one
            _fk, model_name = association_keys(type, assoc_name, config)
            query = ::Dami.db(model_name).where(association_keys(type, assoc_name, config)[0] => @record[:id])
            query = query.where("#{config[:as]}_type".to_sym => Dami::Inflector.singularize(@model_name.to_s).capitalize) if config[:as]
            query.first
          end
        end

        def fetch_polymorphic_belongs_to(config)
          type = @record["#{config[:name]}_type".to_sym]
          id = @record["#{config[:name]}_id".to_sym]
          return nil unless type && id
          model_name = Dami::Inflector.pluralize(type.downcase).to_sym
          ::Dami.db(model_name).find(id)
        end

        def fetch_has_many_through(config)
          through_assoc_name = config[:through]
          through_rel = public_send(through_assoc_name)
          through_records = case through_rel
                            when Dami::Query::Builder then through_rel.to_a
                            when Dami::RecordProxy then [through_rel]
                            else []
                            end
          target_model_name = config[:model] || Dami::Inflector.pluralize(config[:name].to_s).to_sym
          return ::Dami.db(target_model_name).where(id: []) if through_records.empty?
          target_fk_on_intermediate = "#{config[:name].to_s.singularize}_id".to_sym
          target_ids = through_records.map { |r| r[target_fk_on_intermediate] }.compact.uniq
          ::Dami.db(target_model_name).where(id: target_ids)
        end

        def find_association_config(model_config, assoc_name)
          (model_config[:relationships] || {}).each do |type, rels|
            rels.each do |key, opts|
              actual_name = key.is_a?(Hash) ? key.keys.first : key
              if actual_name == assoc_name
                full_opts = opts.is_a?(Hash) ? opts : {}
                full_opts = key.values.first.merge(full_opts) if key.is_a?(Hash)
                return [type, full_opts.merge(name: assoc_name)]
              end
            end
          end
          raise "Association :#{assoc_name} not found on #{@model_name}"
        end

        def association_keys(type, name, config)
          owner_singular = Dami::Inflector.singularize(@model_name.to_s)
          fk = config[:foreign_key] || (config[:as] ? "#{config[:as]}_id".to_sym : "#{owner_singular}_id".to_sym)
          model_name = config[:model] || Dami::Inflector.pluralize(name.to_s).to_sym
          [fk, model_name]
        end
      end

      # Contains the logic for eager-loading associations, which is mixed into the adapter.
      # This code was already correct and remains unchanged.
      module AdapterMethods
        def preload_associations(proxies, relations)
          return proxies if proxies.empty?
          model_name = proxies.first.instance_variable_get(:@model_name)
          model_config = Dami.find_model(model_name)
          relations.each do |rel_name|
            type, config = find_association_config_for_adapter(model_config, rel_name)
            records = proxies.map(&:to_h)
            preloaded_map = if config[:through]
              preload_has_many_through(records, model_name, config)
            else
              case type
              when :belongs_to
                config[:polymorphic] ? preload_polymorphic_belongs_to(records, config) : preload_belongs_to(records, config)
              when :has_many
                preload_has_many(records, model_name, config)
              when :has_one
                preload_has_one(records, model_name, config)
              end
            end
            proxies.each do |proxy|
              preloaded_data = if config[:polymorphic] && type == :belongs_to
                type_val = proxy["#{config[:name]}_type".to_sym]
                id_val = proxy["#{config[:name]}_id".to_sym]
                preloaded_map[[type_val, id_val]]
              else
                preloaded_map[proxy[:id]]
              end
              dynamic_config = if config[:polymorphic] && type == :belongs_to
                type_val = proxy["#{config[:name]}_type".to_sym]
                config.merge(model: Dami::Inflector.pluralize(type_val.downcase).to_sym) if type_val
              else
                config
              end
              proxy.instance_variable_set(:@preloaded, proxy.instance_variable_get(:@preloaded).merge(rel_name => wrap_preloaded_data_for_adapter(rel_name, preloaded_data, dynamic_config)))
            end
          end
          proxies
        end

        private

        def wrap_preloaded_data_for_adapter(assoc_name, data, config)
          return data.is_a?(Array) ? [] : nil if data.nil? || config.nil?
          model_name = config[:model] || Dami::Inflector.pluralize(assoc_name.to_s).to_sym
          if data.is_a?(Array)
            data.map { |r| ::Dami::RecordProxy.new(model_name, r) }
          else
            ::Dami::RecordProxy.new(model_name, data)
          end
        end

        def find_association_config_for_adapter(model_config, assoc_name)
           (model_config[:relationships] || {}).each do |type, rels|
             rels.each do |key, opts|
               actual_name = key.is_a?(Hash) ? key.keys.first : key
               if actual_name == assoc_name
                 full_opts = opts.is_a?(Hash) ? opts : {}
                 full_opts = key.values.first.merge(full_opts) if key.is_a?(Hash)
                 return [type, full_opts.merge(name: assoc_name)]
               end
             end
           end
           raise "Association :#{assoc_name} not found on #{model_config[:name]}"
         end

        def preload_belongs_to(records, config)
          fk = config[:foreign_key] || "#{config[:name]}_id".to_sym
          model_name = config[:model] || Dami::Inflector.pluralize(config[:name].to_s).to_sym
          fk_ids = records.map { |r| r[fk] }.compact.uniq
          return {} if fk_ids.empty?
          related_records = ::Dami.db(model_name).where(id: fk_ids).to_a.map(&:to_h)
          related_map = related_records.each_with_object({}) { |r, h| h[r[:id]] = r }
          records.each_with_object({}) { |r, h| h[r[:id]] = related_map[r[fk]] }
        end

        def preload_polymorphic_belongs_to(records, config)
          name = config[:name]
          records_by_type = records.group_by { |r| r["#{name}_type".to_sym] }
          preloaded_map = {}
          records_by_type.each do |type, recs|
            next unless type
            model_name = Dami::Inflector.pluralize(type.downcase).to_sym
            ids = recs.map { |r| r["#{name}_id".to_sym] }.compact.uniq
            next if ids.empty?
            related_records = ::Dami.db(model_name).where(id: ids).to_a.map(&:to_h)
            related_map = related_records.each_with_object({}) { |r, h| h[r[:id]] = r }
            recs.each do |r|
              preloaded_map[[type, r["#{name}_id".to_sym]]] = related_map[r["#{name}_id".to_sym]]
            end
          end
          preloaded_map
        end

        def preload_has_many(records, owner_model, config)
          owner_ids = records.map { |r| r[:id] }.uniq
          return {} if owner_ids.empty?
          owner_singular = Dami::Inflector.singularize(owner_model.to_s)
          fk = config[:foreign_key] || (config[:as] ? "#{config[:as]}_id".to_sym : "#{owner_singular}_id".to_sym)
          model_name = config[:model] || Dami::Inflector.pluralize(config[:name].to_s).to_sym
          query = ::Dami.db(model_name).where(fk => owner_ids)
          if config[:as]
            type_key = "#{config[:as]}_type".to_sym
            type_value = Dami::Inflector.singularize(owner_model.to_s).capitalize
            query = query.where(type_key => type_value)
          end
          related_records = query.to_a.map(&:to_h)
          grouped = related_records.group_by { |r| r[fk] }
          records.each_with_object({}) { |r, h| h[r[:id]] = grouped[r[:id]] || [] }
        end

        def preload_has_one(records, owner_model, config)
          preloaded = preload_has_many(records, owner_model, config)
          preloaded.transform_values(&:first)
        end

        def preload_has_many_through(records, owner_model, config)
          owner_ids = records.map { |r| r[:id] }.uniq
          return {} if owner_ids.empty?
          through_config = find_association_config_for_adapter(Dami.find_model(owner_model), config[:through])[1]
          through_model_name = through_config[:model] || Dami::Inflector.pluralize(config[:through].to_s).to_sym
          owner_singular = Dami::Inflector.singularize(owner_model.to_s)
          through_fk_on_join = through_config[:foreign_key] || "#{owner_singular}_id".to_sym
          join_records = ::Dami.db(through_model_name).where(through_fk_on_join => owner_ids).to_a.map(&:to_h)
          return {} if join_records.empty?
          target_model_name = config[:model] || Dami::Inflector.pluralize(config[:name].to_s).to_sym
          target_fk_on_join = "#{Dami::Inflector.singularize(target_model_name.to_s)}_id".to_sym
          target_ids = join_records.map { |r| r[target_fk_on_join] }.compact.uniq
          return {} if target_ids.empty?
          target_records = ::Dami.db(target_model_name).where(id: target_ids).to_a.map(&:to_h)
          targets_by_id = target_records.each_with_object({}) { |r, h| h[r[:id]] = r }
          join_records_by_owner_id = join_records.group_by { |r| r[through_fk_on_join] }
          owner_ids.each_with_object({}) do |id, h|
            joins = join_records_by_owner_id[id] || []
            h[id] = joins.map { |j| targets_by_id[j[target_fk_on_join]] }.compact
          end
        end
      end

      # This is the entry point for the plugin. It wires all the pieces together.
      def self.apply(dami_module)
        dami_module.extend(ClassMethods)
        
        # Provides the lazy-loading helpers (e.g., fetch_association) to RecordProxy instances.
        dami_module::RecordProxy.include(RecordProxyMethods)
        
        # This is the core of the optimization. It modifies the initialize process
        # for every RecordProxy to efficiently apply the shared association methods.
        dami_module::RecordProxy.prepend(Module.new do
          def initialize(*args)
            super
            extend Dami.association_module_for(@model_name)
          end
        end)
        
        dami_module::Adapters::Base.include(AdapterMethods)
      end
    end
  end
end