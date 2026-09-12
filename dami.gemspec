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
  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "documentation_uri"     => "#{spec.homepage}/tree/main/docs",
    "rubygems_mfa_required" => "true",
  }

  # Explicit file list from disk (not `git ls-files`), so the gem never depends
  # on what happens to be committed.
  spec.files = Dir[
    "lib/**/*.rb",
    "bin/*",
    "docs/*.md",
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
  ]

  spec.bindir        = "bin"
  spec.executables   = ["dami"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "connection_pool", ">= 2.4", "< 4"
  spec.add_dependency "sqlite3", "~> 2.0"

  spec.add_development_dependency "minitest", "~> 5.16"
  spec.add_development_dependency "minitest-reporters", "~> 1.6"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "benchmark-ips", "~> 2.8"
  spec.add_development_dependency "ruby-prof", "~> 1.6"
end
