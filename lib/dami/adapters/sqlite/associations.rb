# frozen_string_literal: true
module SqliteAssociations
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
        when :has_many then preload_has_many(records, model_name, config)
        when :has_one then preload_has_one(records, model_name, config)
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
          config.merge(model: type_val.downcase.pluralize.to_sym) if type_val
        else
          config
        end
        proxy.instance_variable_get(:@preloaded)[rel_name] = wrap_preloaded_data_for_adapter(rel_name, preloaded_data, dynamic_config)
      end
    end
    proxies
  end
  private
  def wrap_preloaded_data_for_adapter(assoc_name, data, config)
    return data.is_a?(Array) ? [] : nil if data.nil? || config.nil?
    model_name = config[:model] || assoc_name.to_s.pluralize.to_sym
    if data.is_a?(Array)
      data.map { |r| ::Dami::RecordProxy.new(model_name, r) }
    else
      ::Dami::RecordProxy.new(model_name, data)
    end
  end
  def find_association_config_for_adapter(model_config, assoc_name)
    (model_config[:relationships] || {}).each do |type, rels|
      return [type, rels[assoc_name].merge(name: assoc_name)] if rels.key?(assoc_name)
    end
    raise "Association :#{assoc_name} not found"
  end
  def preload_belongs_to(records, config)
    fk = config[:foreign_key] || "#{config[:name]}_id".to_sym
    model_name = config[:model] || config[:name].to_s.pluralize.to_sym
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
      model_name = type.downcase.pluralize.to_sym
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
    fk = config[:foreign_key] || (config[:as] ? "#{config[:as]}_id".to_sym : "#{owner_model.to_s.singularize}_id".to_sym)
    model_name = config[:model] || config[:name].to_s.pluralize.to_sym
    query = ::Dami.db(model_name).where(fk => owner_ids)
    if config[:as]
      type_key = "#{config[:as]}_type".to_sym
      type_value = owner_model.to_s.chomp('s').capitalize
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
    through_model_name = through_config[:model] || config[:through].to_s.pluralize.to_sym
    through_fk_on_join = through_config[:foreign_key] || "#{owner_model.to_s.singularize}_id".to_sym
    join_records = ::Dami.db(through_model_name).where(through_fk_on_join => owner_ids).to_a.map(&:to_h)
    return {} if join_records.empty?
    target_model_name = config[:model] || config[:name].to_s.pluralize.to_sym
    target_fk_on_join = "#{target_model_name.to_s.singularize}_id".to_sym
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