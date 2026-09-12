# Dami 1.0.0 — pre-publish review

> **Status (same day, later):** every item below is fixed in the working tree and staged in git — 92 files, one `git commit` away. The suite ran green 8× in a row: **276 tests, 840 assertions, 0 failures** (up from 262/749 with 18 red). Ran in a sandbox against the system libsqlite3 through a thin shim, not the real `sqlite3` gem, so run `ruby test/run_all.rb` once on your Mac before you commit; that is the only step I could not do for you. Details of what changed: `CHANGELOG.md`, top entry.

_Reviewed 2026-09-12 against the working tree in `~/Desktop/00/zzz/dami`. Static read of every file in `lib/`, the gemspec, Rakefile, docs, test helpers and the flow/association/nested tests. I could not execute the test suite (no sqlite3 gem reachable from my sandbox) — see "What I need from you" at the end._

---

## Verdict

**Publish now: no.** `gem build` fails outright today, and even if it built, the gem would not `require`. Four files that `lib/dami.rb` loads are not committed to git, and the gemspec builds its file list from `git ls-files`. These are mechanical fixes — an hour, not a rewrite.

**Use it as the finance app's data layer: yes, with eyes open.** The core — query builder, parameterised SQL, protection, validations, connection pool, WAL — is sound and reads like something you've actually used. The gaps are all at the edges: schema constraints, timestamps, one real transaction bug in Flows, and two `NoMethodError`s on paths I don't think you've run recently. All fixable, and I've listed the exact fix for each.

The name `dami` is free on rubygems.org (404 as of today).

---

## 1. Publish blockers

These stop `gem build` / `gem push` or ship a broken gem.

**1.1 Required files are untracked → published gem raises LoadError on `require 'dami'`.**
`dami.gemspec` line 16 uses `git ls-files`. These are required by `lib/dami.rb` but have never been committed:

- `lib/dami/localization.rb`
- `lib/dami/dsl_guardrails.rb`
- `lib/dami/validation_rules.rb`
- `lib/dami/plugins/presenter.rb`

Fix: `git add` them (and the new docs). Everything since your last commit on 2025‑10‑18 is uncommitted — the entire "1.0" state lives only in the working tree. Commit it before anything else; that is also your only backup.

**1.2 `gem build` fails right now: tracked files that no longer exist.**
Rubygems validates that every entry in `spec.files` exists. These are tracked but deleted on disk: `docs/2.*.md` through `docs/9.*.md` (renamed to `02.`–`09.`) and `test_db.sqlite3` at the repo root. Fix: `git add -A docs && git rm --cached test_db.sqlite3`.

**1.3 `.DS_Store` files are tracked and will ship inside the gem.**
`lib/.DS_Store`, `lib/dami/.DS_Store`, `lib/dami/adapters/.DS_Store`, `lib/dami/plugins/.DS_Store`, `docs/.DS_Store`. Fix: add a `.gitignore` (there is none) with `.DS_Store`, `*.sqlite3`, `*.db`, `*.db-wal`, `*.db-shm`; then `git rm --cached` them.

**1.4 Seven SQLite blobs are committed** (`test/bench/competitive_benchmark.db` ≈3 MB, `test/competitive_benchmark.db` ≈3 MB, plus five smaller). Excluded from the gem by the `test/` filter, but they bloat the repo forever. Untrack them.

**1.5 The sqlite3 dependency is wrong.** `dami.gemspec:26` says `sqlite3 ~> 1.6`. Your own benchmarks ran on sqlite3 2.7.2 (the path is in `test/bench/compete_results.txt`), and any app on 2.x — the finance app included — could not bundle dami. Fix: `spec.add_dependency "sqlite3", ">= 2.0"`.

**1.6 Missing files rubygems and users expect:** no `README.md` (rubygems renders it as the gem page — right now the page would be blank), no `LICENSE` file despite `license = "MIT"`. Add `spec.metadata["rubygems_mfa_required"] = "true"`, `source_code_uri`, `changelog_uri`, and `spec.required_ruby_version`.

**1.7 Stray files that would ship:** `lib/dami/untitled.rb` (an old draft of `configuration.rb`), `lib/dami/draft.rb` (8 bytes, contains the text "draft.rb"), `lib/dami/flow.rb` (entirely commented out), `lib/dami/locale_manager.rb` (unused duplicate of `localization.rb`), `lib/dami/plugins/scopes.rb` and `lib/dami/plugins/timestamps.rb` (never applied; timestamps references a `ClassMethods` module that does not exist), `lib/dami/adapters/sqlite/associations.rb` (superseded by the plugin, commented out in `core.rb`). Delete all seven.

**1.8 `rake test` is broken.** `Rakefile:10` runs `test/run_tests.rb`; the file is `test/run_all.rb`. It also declares postgres/mysql tasks for adapters that don't exist.

**1.9 The CHANGELOG says "Zero Dependencies".** The gemspec declares `thor` and `connection_pool`. Say so.

---

## 2. Correctness bugs

Ordered by how likely they are to bite the finance app.

**2.1 `Dami.run` commits on Failure. The docs promise the opposite.**
`lib/dami/core.rb:80–88`:

```ruby
Dami.database.transaction do
  result = catch(:halt) { flow.call(context) }
  context.run_after_commit_hooks! if result.is_a?(Success)
  result
end
```

`prepare` fails by `throw :halt, Failure`. `catch` returns normally, the block returns normally, and the sqlite3 gem commits a transaction whose block returns normally. So a flow that writes a row and *then* halts leaves the row in the database. `docs/10.Flows_and_Commands.md:148` says "they all succeed, or they all roll back." Your test `test_flow_halts_on_prepare_failure` halts *before* any write, which is why it passes.

Same block: `run_after_commit_hooks!` runs *inside* the transaction, i.e. before COMMIT is issued — the docs say hooks run only after the commit is permanent.

Fix (both at once):

```ruby
class Rollback < StandardError; end

def self.run(flow_name, **params)
  flow = find_flow(flow_name)
  context = FlowContext.new(params)
  result = nil
  begin
    Dami.database.transaction do
      result = catch(:halt) { flow.call(context) }
      raise Rollback if result.is_a?(Failure)
    end
  rescue Rollback
    # intentional: transaction rolled back, result stays a Failure
  end
  context.run_after_commit_hooks! if result.is_a?(Success)
  result
end
```

Add a test: create a row, then `prepare` something invalid, assert count is 0.

**2.2 `String#singularize` does not exist — two live `NoMethodError`s.**
You moved to `Dami::Inflector` everywhere except two call sites:

- `lib/dami/plugins/associations.rb:88` — lazy `has_many :through` (`post.tags` without `preload`). `test_lazy_load_has_many_through` exercises exactly this line; I expect it to fail.
- `lib/dami/plugins/nested_attributes.rb:48` — any nested write where the `has_many` has no explicit `foreign_key:`. `nested_test.rb` uses `nests :comments` with no foreign key; I expect those to fail too.

Fix: `Dami::Inflector.singularize(...)` at both sites. If your suite is green today, tell me — it would mean something in your environment (ActiveSupport?) is patching `String`, and the gem would still break for everyone else.

**2.3 Foreign keys are never enforced.** `lib/dami/adapters/sqlite/connection.rb:7–13` sets WAL and synchronous but not `PRAGMA foreign_keys = ON`. SQLite defaults it off, per connection. So `Dami::ForeignKeyViolation` can never actually be raised, and a batch can be deleted out from under its expenses. Fix: add `db.execute("PRAGMA foreign_keys = ON;")` in the pool block. (Per-connection pragmas belong there anyway — there is no other hook.)

**2.4 `Dami.locale=` is process-global.** `lib/dami/localization.rb:16–17` stores the locale in a module ivar. Under Puma, one request setting `:gl` leaks into every other thread mid-request. `with_locale` has the same race. Fix: `Thread.current[:dami_locale]`. Not a Phase‑1 problem for the finance app, but it is the exact shape of bug the trilingual site would hit.

**2.5 `create_table` silently drops every constraint.** `lib/dami/adapters/sqlite/schema.rb:87–91` emits only `name TYPE` (+ `PRIMARY KEY AUTOINCREMENT`). `null: false`, `default:`, `unique:`, references — all accepted by `TableDefinition#field` and thrown away. `add_index` (`schema.rb:53`) ignores `unique: true` entirely. So the DSL cannot express "username is unique" or "amount is required"; `UniqueConstraintViolation` only fires on tables you created by hand. This is why your own tests create their tables with raw SQL.

**2.6 Type mapping disagrees with the docs and with itself.** `docs/02.Models_and_Fields.md:42–46` promises `:decimal/:float → REAL`, `:datetime → DATETIME`, `:json → TEXT (auto‑serialized)`. In code, `create_table` maps float/decimal/datetime/date to **TEXT** (`schema.rb:92–98`) while `add_column` maps them to REAL/DATETIME (`migration.rb:60–67`). Nothing serialises JSON — inserting a Hash raises inside sqlite3. Sorting a TEXT float column sorts lexically ("9.5" > "10.2"). Pick one map, put it in one place, and either implement `:json` or remove it from the table.

**2.7 There are no timestamps.** `TableDefinition#timestamps` adds the columns; nothing ever sets them. The plugin file is a stub. Either set `created_at`/`updated_at` in `insert_record`/`update_records`, or drop the helper so it does not promise something.

**2.8 `execute` and `execute_prepared` treat parameters differently.** `execute_prepared` converts `Time`/`Date`/booleans; `execute` (used by `insert_many` and raw calls) does not, so `create_many` with a `Time` value raises. Route both through the same conversion.

**2.9 Validation `min`/`max` use `to_i`.** `validation_rules.rb:15–16`. `"0.50".to_i` is 0, so `rule :amount, min: 0.01` rejects every valid sub‑euro amount. Use `Float(v) rescue nil`.

**2.10 `update` returns and validates against one record while updating many.** `persistence.rb:26–46`: fetches `first`, validates conditionals against it, updates every matching row, returns `first`. The docs say update applies to all matches — fine — but the return value and any `if:` conditions only reflect the first row. Worth stating in the docs, or returning the count.

---

## 3. Smaller things (fix when convenient)

- `schema.rb` defines `column_exists?` twice (lines 22 and 47) and `columns` twice (50 and 68); the second definitions win and use a different type map than the first.
- `Dami.db(model)` builds a fresh anonymous `Class.new(Builder)` on every call when the model has scopes (`core.rb:92–101`). Cache it per model.
- Every row gets its presenter extended and fallback accessors defined twice — once in the prepended `initialize`, again in `Dami.wrap_record`. Harmless, but it is most of the per-row cost in your own profile.
- The prepared-statement cache (`query.rb:99–102`) never finalises statements and grows per distinct SQL string; `IN (?,?,?)` with varying counts makes that unbounded over time.
- `Query::Enumerable#_wrap_record_with_presenter` is unused.
- `core.rb:90` `private` does nothing for `def self.` methods (use `private_class_method`).
- `where(hash)` interpolates the *keys* into SQL. Values are bound; keys are not. Document loudly: never pass a user-supplied hash to `where`.
- `docs/1.Getting_Started.md` and `docs/01.Getting_Started.md` both exist with different content. Keep one.

---

## 4. What is genuinely good

Saying this because it is true, not to soften the list above.

- **The write path is hardened by default.** `filter_input!` raises on unknown fields, `protect`/`permit` is explicit, and `create_many` no longer bypasses it. That is a better default than ActiveRecord's.
- **SQL is parameterised everywhere it matters**, `ORDER BY` fragments are validated against `\A[\w.]+\z`, `limit`/`offset` are coerced with `to_i`.
- **The connection layer is right for a small multi-user app**: pool, WAL, `busy_timeout`, reentrant transactions via `connection_pool`, and semantic exceptions for unique-constraint failures with the column name extracted.
- **Validation contexts (`on :create` / `on :update`, `if:`/`unless:`/`when:`) and partial validation on update** are cleanly designed.
- **The four-pillar DSL with guardrails** (`InvalidDSLError` pointing at the right block) is a real developer-experience win.
- **Flows/Commands/Drafts** are a good idea and mostly well built — 2.1 is the one hole.
- **Test breadth is real**: 30 files covering pools, unicode, constraints, polymorphism, nesting three deep. It is a suite worth keeping green.

---

## 5. What this means for the finance app

Assuming the fixes in §1 and §2.1–2.3 land first (they are small):

- **Schema by hand, in SQL.** The finance schema needs `NOT NULL`, `UNIQUE (username)`, foreign keys and defaults. Dami's DSL cannot express them, so the tables get created with `Dami.database.execute("CREATE TABLE …")` — exactly how your own test suite does it. Models still get declared with `Dami.model` for fields, relationships, validations and protection.
- **Money stays integer cents** (`amount_cents`). Never a float column.
- **Dates and times come back as strings** (`'2026-09-12'`, `'2026-09-12 18:40:00'` UTC). Parse in the view layer; set `created_at` yourself on create.
- **Foreign keys** need 2.3 or the batch/expense relationship is unenforced.
- **Locale**: irrelevant for Phase 1 (English UI for two people). 2.4 matters the day this app or the site goes multilingual.
- **Concurrency**: two users on Puma is well within what the pool + WAL + `busy_timeout` handle.

---

## 6. What I need from you

1. **Run the suite and paste the last ~20 lines:** `cd ~/Desktop/00/zzz/dami && ruby test/run_all.rb`. That turns my two "expected failures" into facts and tells us whether anything else is red.
2. **Delete a lock file I left behind.** My `git status` in your repo could not remove its own lock (my shell on your Mac cannot delete files): `rm ~/Desktop/00/zzz/dami/.git/index.lock`. Until you do, every git command in that repo will refuse to run.
3. **Decide who applies the fixes.** §1 is git hygiene you should probably do yourself in one commit. §2.1–2.3 I can patch and hand you as a diff, with tests, if you want.
