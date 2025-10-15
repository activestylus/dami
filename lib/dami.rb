# frozen_string_literal: true
require_relative "dami/version"
require_relative "dami/actions/draft"
require_relative "dami/errors"
require_relative "dami/result"
require_relative "dami/plugins/associations"
require_relative "dami/plugins/nested_attributes"
require_relative "dami/plugins/timestamps"
require_relative "dami/plugins/validations"
require_relative "dami/plugins/protection"
require_relative "dami/record_proxy"
require_relative "dami/adapters/base"
require_relative "dami/adapters/sqlite/core"
require_relative "dami/migration"
require_relative "dami/migrator"
require_relative "dami/schema"
require_relative "dami/configuration"
require_relative "dami/command"
require_relative "dami/flow"
require_relative "dami/query/builder"
require_relative "dami/core"
module Dami
  plugin Plugins::Validations
  plugin Plugins::Associations
  plugin Plugins::Protection
end