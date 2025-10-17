# frozen_string_literal: true
require 'sqlite3'
require 'json'
require_relative '../base'
require_relative 'connection'
require_relative 'query'
require_relative 'schema'
#require_relative 'associations'
module Dami
  module Adapters
    class Sqlite < Base
      include SqliteConnection
      include SqliteQuery
      include SqliteSchema
      include Dami::Plugins::Associations::AdapterMethods
      #include SqliteAssociations
    end
  end
end