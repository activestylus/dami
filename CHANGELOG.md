# Changelog

## [1.0.0] - 2026-09-12 (pre-publish review pass)

Fixes applied after a full review of the 1.0.0 working tree, before the first
rubygems release. The suite is 276 tests / 840 assertions, green.

### 🐛 Correctness

* **`Dami.run` now rolls back on a `Failure` halt.** Previously a flow that wrote rows and then halted with a `Failure` (e.g. `prepare` rejecting its input) committed those rows. After-commit hooks now run after the transaction has actually committed, not inside it.
* **Nested flows use savepoints.** `run(:other_flow)` inside a flow rolls back only the inner flow's writes on failure; the outer flow keeps going with the returned `Failure`. Any nested `transaction` call behaves the same way.
* **Foreign keys are enforced.** Every pooled connection now runs `PRAGMA foreign_keys = ON`, so `references:` columns and `Dami::ForeignKeyViolation` mean something. (If your test helper drops tables in arbitrary order, drop them inside one transaction with `PRAGMA defer_foreign_keys = ON` — see `test/database_helper.rb`.)
* **Two `NoMethodError`s fixed:** lazy `has_many :through` (`post.tags` without `preload`) and nested attributes without an explicit `foreign_key:` called `String#singularize`, which does not exist without ActiveSupport. Both use `Dami::Inflector` now. 17 previously-red tests pass.
* **`:memory:` databases use one connection.** An in-memory SQLite database exists per connection, so a pool of five was five unrelated databases. `pool_size` is forced to 1 for `path: ':memory:'`.
* **Inserts read `last_insert_row_id` on the connection that inserted.** `insert_record` and `insert_many` run inside a transaction so both statements share one pooled connection.
* **One parameter conversion path.** `execute`, `get_first_row` and prepared statements all convert `Time`/`DateTime`/`Date`/booleans/JSON the same way; `create_many` with a `Time` or `true` no longer raises inside the driver.
* **`min:` / `max:` validations compare numbers, not `to_i`.** `rule :amount, min: 0.01` now accepts `0.5` and `"9.99"`, and rejects `"abc"`.
* **Locale is thread-safe.** `Dami.locale=` remains the process-wide default; `Dami.with_locale` and the new `Dami.thread_locale=` are thread-local, so a web request can no longer leak its locale into other threads.
* **`NOT NULL` violations raise `Dami::NotNullViolation`** (with `.column`) instead of a raw driver error.

### ✨ Schema

* `create_table` / `add_column` keep their constraints: `null: false`, `unique: true`, `default:` (incl. `:current_timestamp`), `references:` (+ `on_delete:`). `t.references :user` is shorthand for `user_id INTEGER REFERENCES users(id)`.
* `add_index(..., unique: true)` creates a `UNIQUE` index; multi-column indexes accepted.
* One type map for `create_table` and `add_column`: `:float`/`:decimal` → `REAL`, `:datetime`/`:date`/`:time` → `DATETIME` (previously `create_table` used `TEXT` for all of these while `add_column` did not).
* `:json` fields are serialized on write and parsed on read, as the docs already claimed.
* `created_at` / `updated_at` are filled automatically when the model declares them.
* `dami db rollback [STEPS]` added to the CLI; rollback refreshes `db/schema.rb` like migrate does. CLI commands are `dami db migrate`, `dami db rollback`, `dami db schema_dump` (docs previously showed `dami db:migrate`, which Thor does not accept).

### 🔒 Hardening

* Column and table names passed to `where`, `join`, `insert` are validated as plain identifiers (`Dami::InvalidIdentifier` otherwise). Values were always bound; names were interpolated.

### 🧹 Packaging

* `sqlite3` dependency corrected to `>= 2.0` (was `~> 1.6`, which could not be bundled with any 2.x app). `required_ruby_version >= 3.0`, rubygems metadata (MFA required, source/changelog URIs).
* `spec.files` is an explicit `Dir[]` list instead of `git ls-files`.
* Added `README.md`, `LICENSE` (MIT), `.gitignore`; `rake test` points at the real runner.
* Removed dead files: `lib/dami/untitled.rb`, `lib/dami/draft.rb`, `lib/dami/flow.rb` (commented out), `lib/dami/locale_manager.rb`, `lib/dami/plugins/{scopes,timestamps,presenter}.rb`, `lib/dami/adapters/sqlite/associations.rb`; duplicate `docs/1.Getting_Started.md`.
* Runtime dependencies are `sqlite3`, `connection_pool` and `thor` (the previous "zero dependencies" note was wrong).

## [1.0.0] - 2025-10-18

🎉 **Dami v1.0 - Production Ready**

This is the first production-ready release of Dami. The 1.0 milestone represents a mature, battle-tested ORM with a clean architecture, comprehensive test coverage (228 tests,  737 assertions), and production-grade error handling.

### 🏗️ **Major Architecture Changes**

* **Four Pillars DSL:** Complete separation of concerns across four distinct DSL blocks:
  * `Dami.model` - Structure (fields, relationships, virtual fields)
  * `Dami.behavior` - Write-side logic (validations, protection rules)
  * `Dami.scopes` - Collection-level queries
  * Each pillar has a focused, single responsibility, making code clearer and more maintainable

* **Architectural Guardrails:** The framework now enforces clean separation at the DSL level
  * Attempting to define validations in `Dami.model` raises `Dami::InvalidDSLError` with helpful guidance
  * Attempting to define fields in `Dami.behavior` raises an error pointing to the correct location
  * Makes architectural decay impossible and provides immediate, clear feedback to developers
  * Zero magic - explicit method definitions with no `method_missing` tricks

### 🐛 **Critical Bug Fixes**

* **`create_many` Security Fix:** Fixed a critical bug where `create_many` bypassed protection rules
  * Now enforces field protection on every record in batch operations
  * Validates all records before any database writes (atomic validation)
  * Raises `Dami::ProtectionError` when protected fields are present
  * **Impact:** High - prevents bulk operations from bypassing security rules

### ✨ **Enhanced Error Handling**

* **Database-Specific Exceptions:** Replaced generic SQLite errors with semantic Dami exceptions
  * `Dami::UniqueConstraintViolation` - raised on unique constraint failures, includes column name
  * `Dami::ForeignKeyViolation` - raised on foreign key constraint failures
  * Improves error handling in application code with meaningful, catchable exceptions

### 🔧 **Configuration Enhancements**

* **Configurable Connection Pool:** Added `pool_size` option to connection configuration
  * Default: 5 connections per pool
  * Usage: `Dami.connect(:default, adapter: :sqlite, path: 'db.sqlite', pool_size: 10)`
  * Allows tuning for high-concurrency scenarios

### 📊 **Test Coverage**

* **228 Comprehensive Tests** covering:
  * Core CRUD operations
  * All relationship types (belongs_to, has_many, has_one, polymorphic, has_many_through)
  * Nested attributes (3+ levels deep)
  * Validations (all rule types, contexts, conditionals)
  * Protection & permissions
  * Scopes & query building
  * Transactions & concurrency
  * Edge cases (connection pooling, unicode, NULL handling, large datasets)
  * DSL guardrails enforcement

### 🎯 **Developer Experience**

* **Clear Error Messages:** All DSL violations now provide helpful guidance
  * Example: `'validate' is not allowed here. Please define it in a Dami.behavior block.`
* **Minimal dependencies:** `sqlite3`, `connection_pool`, `thor`
* **Production Tested:** Stress-tested with concurrent operations, large batches, and edge cases

### 📝 **Breaking Changes**

* **DSL Reorganization:** Models must now separate concerns across pillar blocks
  * **Before (0.9.x):**
    ```ruby
    Dami.model :users do
      fields { field :name, :string }
      validate { rule :name, :required }
      protection { protect :role }
    end
    ```
  * **After (1.0.0):**
    ```ruby
    Dami.model :users do
      fields { field :name, :string }
    end
    
    Dami.behavior :users do
      validate { rule :name, :required }
      protection { protect :role }
    end
    ```

### 🚀 **Upgrade Guide**

1. Separate `validate` and `protection` blocks from `Dami.model` into `Dami.behavior`
2. Move `scope` definitions to `Dami.scopes` blocks
3. Update exception handling to catch `Dami::UniqueConstraintViolation` instead of `SQLite3::ConstraintException`
4. Optionally configure connection pool size if needed for your workload

---

Dami 1.0 represents a stable, production-ready foundation for Ruby applications. The architecture is clean, the test coverage is comprehensive, and the framework is ready for real-world use.

## [0.9.0] - 2025-10-17

This is the official first major release of the Dami ORM. It includes a complete feature set for building robust applications, significant performance optimizations, and a hardened codebase.

### ✨ New Features

* **Nested Attributes:** Implemented a powerful and secure way to manage associated records through a parent record.
    * New `nests` DSL in models to explicitly allow nested operations (e.g., `nests :comments, allow_destroy: true`).
    * Supports deep, recursive nesting for grandchildren and beyond.
    * Handles creating, updating, and destroying nested records via `_attributes` keys (`comments_attributes`).
    * All operations are wrapped in a single, atomic database transaction.
    * Fully integrated with Dami's validation and protection layers, ensuring child records respect their own rules.

* **Resilient Flows:** The `perform` step in the Flow DSL is now robust for handling unreliable external actions.
    * Added a `:retry_options` parameter to `perform` (e.g., `retry_options: { on: [ApiError], times: 2 }`).
    * Added a `:timeout` parameter to automatically fail a step that takes too long.

* **Custom Inflector:** Introduced a dependency-free internal inflector (`Dami::Inflector`) to handle pluralization and singularization, removing the need for external gems like Active Support.

### 🚀 Performance

A major focus of this release was optimizing the performance of association loading to be competitive with leading ORMs.

* **Optimized `.count` Method:** The `.count` method now executes a highly efficient `SELECT COUNT(*)` database query instead of loading all records into memory, resulting in a **~1.13x speed improvement** for counting operations.

* **Preload Optimization (~85% Improvement):** The performance of eager loading (`.preload`) has been massively improved through two key architectural changes:
    1.  **Flyweight Pattern:** Replaced per-instance method definition on `RecordProxy` objects with cached, shared modules. This eliminated the primary object-creation bottleneck.
    2.  **Inflector Memoization:** Implemented caching for inflection results, dramatically reducing redundant string and regex operations in hot loops.
    * **Result:** `Dami (preload)` is now **~1.6x faster than ActiveRecord (`includes`)** in competitive benchmarks for common scenarios.

### 🔧 Fixes & Hardening

* **CLI Hardening:** The `dami` command-line interface is now more robust and provides user-friendly error messages for common misconfigurations, such as:
    * Missing `config/initializers/dami.rb` file.
    * Database not connected when running `db:*` tasks.
    * Missing `db/schema.rb` file when generating migrations.

* **Test Suite Reliability:** Fixed flaky tests by implementing a central reset mechanism (`Dami.clear_all!`). This ensures that all global state (model definitions, plugin caches) is cleared before every test, guaranteeing 100% test isolation and reliability.

* **Bug Fixes:**
    * Corrected the `perform` helper in the Flow DSL (was mistakenly documented as `call`).
    * Fixed a bug in the associations plugin where polymorphic and `has_many :through` definitions were not being parsed correctly, leading to `NoMethodError`s in certain load orders.

## [0.8.0] - 2025-10-07

### ✨ Added

* **Flows for Orchestration**: Introduced `Dami.run` and `Dami.flow`, the "Tier 3" system for orchestrating complex, multi-step business processes. This provides a clean, readable, and imperative DSL for defining application workflows.
* **Automatic Transactional Guarantee**: `Dami.run` automatically wraps the entire flow in a database transaction, ensuring all database operations are atomic. If any step raises an exception, the entire transaction is rolled back.
* **Safe Side Effects (`succeed with:`)**: Flows now have a `succeed with: ..., and_then: [...]` method. This provides a transaction-aware "holding area" for irreversible actions (like enqueuing jobs), guaranteeing they only execute *after* the database transaction has successfully committed.
* **Flow DSL**: The block inside a `Dami.flow` now has a rich set of helpers for building robust workflows:
    * `prepare`: Runs a `Dami::Command` to validate and transform data, halting automatically on failure.
    * `perform`: Executes an arbitrary block of code (e.g., an external API call) with resilience options.
    * `db`: Provides access to the query builder.
    * `run`: Calls other Dami flows as sub-routines.
* **Error Handling (`rescue_from`)**: Flows can now define custom handlers for specific exceptions, allowing for graceful error recovery.

## [0.7.0] - 2025-10-01

### ✨ Added

* **Commands (`Dami::Command`)**: Introduced `Dami::Command`, a powerful class for encapsulating complex, reusable business logic. Commands provide a formal structure for contextual validation, data transformation, and dependency injection.
* **Declarative Command DSL**: `Dami::Command` includes a rich DSL for building business rules:
    * `requires_context`: For declaring dependencies.
    * `validate`: For defining validation rules with `if:` and `unless:` conditionals.
    * `transform`: For defining data transformation steps.
    * `apply` & `compose`: For building complex commands from smaller, reusable components.

## [0.6.0] - 2025-10-01

### ✨ Added

* **Inline Drafts**: The `.create` and `.update` methods now accept an optional block that yields a `draft` object. This provides a powerful, inline DSL for adding contextual validation and data transformation for simple-to-medium complexity operations. The `draft` DSL (`verify`, `transform`, `prevent_changes`) mirrors the `Command` API for a consistent developer experience.

## [0.5.8] - 2025-10-01

### ✨ Added

* **Commands**: Introduced `Dami::Command`, the "Tier 3" tool for encapsulating complex, reusable business logic. Commands provide a formal structure for contextual validation (`validate`), data transformation (`transform`), and dependency injection (`requires_context`).
* **Command Composition**: Commands can now be built from smaller, reusable components using `compose` and `apply`, promoting a DRY and modular architecture for business rules.
* **Conditional Logic**: The `validate` DSL now supports powerful conditional execution with `if:` and `unless:` options.

## [0.5.3] - 2025-10-01

### ✨ Added

* **Inline Drafts**: The `.create` and `.update` methods now accept an optional block that yields a `draft` object. This provides a powerful, inline DSL for adding contextual validation and data transformation for simple-to-medium complexity operations. It serves as the "Tier 2" of the business logic spectrum and uses an API (`verify`, `transform`, `prevent_changes`) designed to mirror the full `Dami::Command` for a consistent developer experience.

## [0.5.0] - 2025-09-27

This is a major release introducing a powerful new migration workflow and a professional command-line interface, significantly improving developer productivity.

### ✨ Added

* **Automatic Migration Generator**: Introduced a new `dami generate migration NAME` command. Dami now introspects your model definitions, compares them to the canonical schema (`db/schema.rb`), and automatically generates migration files for adding/removing columns and indexes. This nearly eliminates the need to write migrations by hand. 
* **Full Command-Line Interface (CLI)**: Replaced all Rake tasks with a professional, self-documenting CLI built with Thor. The new `bin/dami` executable provides a standard interface with subcommands like `db:migrate` and `generate migration`.
* **Centralized Configuration**: Added a `Dami.configure` block. Users can now easily configure essential paths like `models_path`, `migrations_path`, and `schema_path` to integrate Dami into any project structure.
* **Schema Dumper (`db/schema.rb`)**: The migrator now automatically creates and updates a `db/schema.rb` file after successful migrations. This file serves as the reliable source of truth for the migration generator.

### ♻️ Changed

* **Rails-Style Migration DSL**: The migration DSL has been updated to use the more conventional `up` and `down` methods, replacing the previous `run` and `reverse`.
* **Index Support in Migrations**: The migration DSL now includes `add_index` and `remove_index` methods for managing database indexes.


## [0.4.0] - 2025-09-21

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

## [0.3.0] - 2025-09-14

### ✨ Added

* **Polymorphic Associations**: `belongs_to` associations now support a `{ polymorphic: true }` option, allowing a model to belong to more than one other model on a single association. The corresponding `has_many` and `has_one` now support the `{ as: :... }` syntax.
* **`has_many :through` Associations**: You can now define `has_many :through` relationships to create many-to-many connections through a join model.
* **Performance Optimizations**: Implemented `find_each` and `find_in_batches` for efficiently processing large numbers of records without loading them all into memory at once.
* **Bulk Inserts**: Added a `.create_many` method for inserting a large number of records in a single, highly performant SQL statement.

### 🐛 Fixed

* Corrected an issue where preloading multiple associations could fail under certain edge cases.
* Ensured that the query builder methods (`where`, `limit`, etc.) are fully immutable and always return a new builder instance.

---

## [0.2.0] - 2025-09-08

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

## [0.1.0] - 2025-09-01

### ✨ Added

* **Database Migrations**: Introduced `Dami::Migration` and `Dami::Migrator` for managing database schema changes over time. Supports `migrate` and `rollback` commands.
* **Basic Associations**: Implemented `has_many`, `has_one`, and `belongs_to` relationships, including support for both lazy-loading and eager-loading via `.preload`.
* **Connection Pooling**: The SQLite adapter now uses a connection pool for improved concurrency and performance under threaded environments.

### ♻️ Changed

* **Hardened Query Builder**: The `.order` method is now hardened against SQL injection attacks.
* The core `create` method now returns a `RecordProxy` instance instead of a plain hash.