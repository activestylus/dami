# frozen_string_literal: true

require_relative "lib/dami/version"

Gem::Specification.new do |spec|
  spec.name        = "dami"
  spec.version     = Dami::VERSION
  spec.authors     = ["Steven Garcia"]
  spec.email       = ["stevendgarcia@gmail.com"]

  spec.summary     = "A lightweight, policy oriented ORM for Ruby."
  spec.description = "Dami is a modern, minimal ORM focusing on a clean query DSL, explicit data validation, and secure attribute protection."
  spec.homepage    = "https://github.com/activestylus/dami"
  spec.license     = "MIT"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end

  spec.bindir        = "bin"
  spec.executables   = ["dami"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "connection_pool", "~> 2.4"
  spec.add_dependency "sqlite3", "~> 1.6"
end