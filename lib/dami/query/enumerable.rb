module Dami
  module Query
    module Enumerable
      def each(&block)
        to_a.each(&block)
      end

      def to_a
        query_structure = build_query_structure
        records = adapter.query_records(query_structure)
        proxies = records.map { |r| Dami.wrap_record(@model_name, r) }
        @preload.empty? ? proxies : adapter.preload_associations(proxies, @preload)
      end
      alias_method :all, :to_a

      def find(id)
        record = adapter.find_record(@model_name, id)
        Dami.wrap_record(@model_name, record)
      end
      def find_each(batch_size: 1000, &block)
        find_in_batches(batch_size: batch_size) do |batch|
          batch.each(&block)
        end
      end
      
      def find_in_batches(batch_size: 1000)
        query = @order_by ? self : order(:id)
        offset = 0
        loop do
          records = query.limit(batch_size).offset(offset).to_a
          break if records.empty?
          yield records
          break if records.length < batch_size
          offset += records.length
        end
      end

      def first
        limit(1).to_a.first
      end

      def last
        reverse_order_query.first
      end

      def any?
        adapter.query_exists?(build_query_structure)
      end

      def exists?(conds = nil)
        conds ? where(conds).any? : any?
      end

      # This is the updated method
      def count
        adapter.count_records(build_query_structure)
      end
      alias_method :length, :count
      alias_method :size, :count
    end
  end
end
