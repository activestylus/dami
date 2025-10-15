require_relative 'schema/dumper'
require_relative 'schema/loader'
require_relative 'schema/introspector'
require_relative 'schema/diff'
require_relative 'schema/generator'

module Dami
  # This method provides the DSL context for db/schema.rb
  def self.define_schema(&block)
    # This is intentionally a placeholder. The Schema::Loader will provide
    # the actual implementation when it loads the schema file.
  end
end