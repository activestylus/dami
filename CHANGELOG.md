# Changelog


## [0.7.0] - 2025-10-01

### ✨ Added

* **Inline Drafts**: The `.create` and `.update` methods now accept an optional block that yields a `draft` object. This provides a powerful, inline DSL for adding contextual validation and data transformation for simple-to-medium complexity operations. It serves as the "Tier 2" of the business logic spectrum and uses an API (`verify`, `transform`, `prevent_changes`) designed to mirror the full `Dami::Command` for a consistent developer experience.

## [0.6.0] - 2025-09-27

This is a major release introducing a powerful new migration workflow and a professional command-line interface, significantly improving developer productivity.

### ✨ Added

* **Automatic Migration Generator**: Introduced a new `dami generate migration NAME` command. Dami now introspects your model definitions, compares them to the canonical schema (`db/schema.rb`), and automatically generates migration files for adding/removing columns and indexes. This nearly eliminates the need to write migrations by hand. 
* **Full Command-Line Interface (CLI)**: Replaced all Rake tasks with a professional, self-documenting CLI built with Thor. The new `bin/dami` executable provides a standard interface with subcommands like `db:migrate` and `generate migration`.
* **Centralized Configuration**: Added a `Dami.configure` block. Users can now easily configure essential paths like `models_path`, `migrations_path`, and `schema_path` to integrate Dami into any project structure.
* **Schema Dumper (`db/schema.rb`)**: The migrator now automatically creates and updates a `db/schema.rb` file after successful migrations. This file serves as the reliable source of truth for the migration generator.

### ♻️ Changed

* **Rails-Style Migration DSL**: The migration DSL has been updated to use the more conventional `up` and `down` methods, replacing the previous `run` and `reverse`.
* **Index Support in Migrations**: The migration DSL now includes `add_index` and `remove_index` methods for managing database indexes.


## [0.5.0] - 2025-09-21

### ✨ Added

* **OR Conditions**: The query builder now supports chainable `.or` conditions for building complex queries (e.g., `.where(name: 'A').or(status: 'active')`).
* **LEFT Joins**: Added a `.left_join` method to the query builder for performing `LEFT OUTER JOIN`s, allowing you to find records that may not have an associated record.
* **Advanced String Matching**: `where` clauses now support `starts_with`, `contains`, and `ends_with` for generating `LIKE` queries (e.g., `where(name: { starts_with: 'A' })`).
* **NOT IN Queries**: Added a `{ not_in: [...] }` operator to `where` clauses for `NOT IN` conditions.
* **Existence Checks**: Added performant `.any?` and `.exists?` methods to the query builder, which use `LIMIT 1` for efficient database checks.
* **First/Last Methods**: Added efficient `.first` and `.last` methods to the query builder. `.last` intelligently reverses the query's sort order.

### ♻️ Changed

* **Major Internal Refactor**: The entire test suite has been refactored to be database-agnostic. It can now run against SQLite, PostgreSQL, and MySQL via the `DB` environment variable.
* **Transactional Tests**: The test suite now uses a transactional cleanup strategy for significantly faster and more reliable test isolation, eliminating file I/O issues.

---

## [0.4.0] - 2025-09-14

### ✨ Added

* **Polymorphic Associations**: `belongs_to` associations now support a `{ polymorphic: true }` option, allowing a model to belong to more than one other model on a single association. The corresponding `has_many` and `has_one` now support the `{ as: :... }` syntax.
* **`has_many :through` Associations**: You can now define `has_many :through` relationships to create many-to-many connections through a join model.
* **Performance Optimizations**: Implemented `find_each` and `find_in_batches` for efficiently processing large numbers of records without loading them all into memory at once.
* **Bulk Inserts**: Added a `.create_many` method for inserting a large number of records in a single, highly performant SQL statement.

### 🐛 Fixed

* Corrected an issue where preloading multiple associations could fail under certain edge cases.
* Ensured that the query builder methods (`where`, `limit`, etc.) are fully immutable and always return a new builder instance.

---

## [0.3.0] - 2025-09-08

### ✨ Added

* **Comprehensive Validation System**: Introduced a powerful `validate` block for model definitions.
    * Supports contextual validations with `on :create` and `on :update`.
    * Supports conditional validations using `if:`, `unless:`, `when:`.
    * Added bulk-application helpers like `all except:` and `all only:`.
* **Virtual Fields**: Models now support a `virtual` block to define attributes that are validated but not persisted to the database (e.g., `password_confirmation`).
* **Attribute Protection**: Implemented a `protection` block with `.protect` and `.permit` to prevent mass-assignment vulnerabilities. Operations can bypass this using the `permit: [...]` or `protect: false` options.
* **Scope DSL**: Added a `scopes` block to define reusable query scopes on models (e.g., `scope :active, -> { where(status: 'active') }`).

### 🐛 Fixed

* Ensured that unknown fields in `create` or `update` calls raise an `UnknownFieldsError` *before* validations are run, providing clearer error messages.

---

## [0.2.0] - 2025-09-01

### ✨ Added

* **Database Migrations**: Introduced `Dami::Migration` and `Dami::Migrator` for managing database schema changes over time. Supports `migrate` and `rollback` commands.
* **Basic Associations**: Implemented `has_many`, `has_one`, and `belongs_to` relationships, including support for both lazy-loading and eager-loading via `.preload`.
* **Connection Pooling**: The SQLite adapter now uses a connection pool for improved concurrency and performance under threaded environments.

### ♻️ Changed

* **Hardened Query Builder**: The `.order` method is now hardened against SQL injection attacks.
* The core `create` method now returns a `RecordProxy` instance instead of a plain hash.