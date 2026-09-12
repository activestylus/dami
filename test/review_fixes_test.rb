# File: test/review_fixes_test.rb
# Regression tests for the fixes made in the 2026-09-12 pre-publish review.
require_relative 'test_helper'

class ReviewFixesTest < Minitest::Test
  class RejectEverything < Dami::Command; end

  def setup
    super
    # actions_test.rb wipes every Command subclass's definitions in its own
    # setup, so (re)declare ours here rather than at class-definition time.
    RejectEverything.clear_definitions!
    RejectEverything.validate(:never, error: "rejected") { false }
  end

  # --- Flows -----------------------------------------------------------------

  def test_flow_rolls_back_writes_made_before_a_failure_halt
    Dami.flow :write_then_fail do
      db(:users).create(first_name: 'Ghost', status: 'active')
      prepare RejectEverything, with: { anything: 1 }
      succeed with: {}
    end

    result = Dami.run(:write_then_fail)

    assert result.failure?
    assert_equal({ never: ["rejected"] }, result.error)
    assert_equal 0, @db[:users].count, "a Failure halt must roll back the flow's writes"
  end

  def test_after_commit_hooks_run_outside_the_transaction
    seen_inside_transaction = :unset
    Dami.flow :hook_timing do
      db(:users).create(first_name: 'Hook', status: 'active')
      succeed with: :ok, and_then: -> { seen_inside_transaction = !Thread.current[:dami_sqlite_connection].nil? }
    end

    result = Dami.run(:hook_timing)

    assert result.success?
    assert_equal false, seen_inside_transaction, "hooks must run after the transaction has committed"
    assert_equal 1, @db[:users].count
  end

  def test_nested_flow_failure_rolls_back_only_its_own_writes
    Dami.flow :inner_fails do
      db(:users).create(first_name: 'Inner', status: 'active')
      prepare RejectEverything, with: { anything: 1 }
      succeed with: {}
    end
    Dami.flow :outer_survives do
      db(:users).create(first_name: 'Outer', status: 'active')
      inner = run(:inner_fails)
      succeed with: inner
    end

    result = Dami.run(:outer_survives)

    assert result.success?
    assert result.value.failure?, "the inner Failure is returned to the outer flow"
    assert_equal ['Outer'], @db[:users].to_a.map { |u| u[:first_name] }
  end

  # --- Connection / constraints ---------------------------------------------

  def test_foreign_keys_are_enforced
    @db.execute("CREATE TABLE parents (id INTEGER PRIMARY KEY)")
    @db.execute("CREATE TABLE children (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES parents(id))")
    Dami.model(:children) { fields { field :parent_id, :integer } }

    assert_raises(Dami::ForeignKeyViolation) do
      @db[:children].create(parent_id: 999)
    end
  end

  def test_not_null_violations_are_semantic_errors
    @db.execute("CREATE TABLE strict (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
    Dami.model(:strict) { fields { field :name, :string } }

    error = assert_raises(Dami::NotNullViolation) { @db[:strict].create(name: nil) }
    assert_equal :name, error.column
  end

  def test_create_many_converts_times_and_booleans
    ids = @db[:posts].create_many([
      { title: 'A', published: true, published_at: Time.utc(2026, 9, 12, 10, 0, 0) },
      { title: 'B', published: false, published_at: Time.utc(2026, 9, 13, 10, 0, 0) }
    ]).map { |p| p[:id] }

    rows = @db[:posts].where(id: ids).order(:id).to_a
    assert_equal [true, false], rows.map { |r| r[:published] }
    assert_equal '2026-09-12 10:00:00', rows.first[:published_at]
  end

  # --- Fields ----------------------------------------------------------------

  def test_json_fields_round_trip
    @db.execute("CREATE TABLE settings (id INTEGER PRIMARY KEY, prefs TEXT)")
    Dami.model(:settings) { fields { field :prefs, :json } }

    record = @db[:settings].create(prefs: { 'theme' => 'dark', 'sizes' => [1, 2] })

    assert_equal({ 'theme' => 'dark', 'sizes' => [1, 2] }, record[:prefs])
    assert_equal({ 'theme' => 'dark', 'sizes' => [1, 2] }, @db[:settings].find(record[:id])[:prefs])
    assert_equal '{"theme":"dark","sizes":[1,2]}', @db.execute("SELECT prefs FROM settings").first['prefs']
  end

  def test_timestamps_are_filled_when_the_model_declares_them
    @db.execute("CREATE TABLE stamped (id INTEGER PRIMARY KEY, name TEXT, created_at DATETIME, updated_at DATETIME)")
    Dami.model(:stamped) do
      fields do
        field :name, :string
        field :created_at, :datetime
        field :updated_at, :datetime
      end
    end

    record = @db[:stamped].create(name: 'one')
    refute_nil record[:created_at]
    refute_nil record[:updated_at]
    assert_match(/\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\z/, record[:created_at])

    created_at = record[:created_at]
    updated = @db[:stamped].where(id: record[:id]).update(name: 'two', updated_at: Time.utc(2030, 1, 1))
    assert_equal created_at, updated[:created_at], "update must not touch created_at"
    assert_equal '2030-01-01 00:00:00', updated[:updated_at], "an explicit updated_at wins"
  end

  def test_timestamps_are_not_touched_for_models_without_them
    record = @db[:tags].create(name: 'plain')
    refute record.to_h.key?(:created_at)
  end

  # --- Query safety ----------------------------------------------------------

  def test_where_rejects_keys_that_are_not_identifiers
    assert_raises(Dami::InvalidIdentifier) do
      @db[:users].where("id = 1; DROP TABLE users; --" => 1).to_a
    end
    assert_raises(Dami::InvalidIdentifier) do
      @db[:users].join("posts; DROP TABLE users", id: :user_id).to_a
    end
    assert_equal [], @db[:users].where('users.id' => 1).to_a, "dotted identifiers stay allowed"
  end

  # --- Validation ------------------------------------------------------------

  def test_min_and_max_compare_decimals_as_numbers
    Dami.model(:prices) { fields { field :amount, :float } }
    Dami.behavior(:prices) { validate { rule :amount, min: 0.01, max: 10 } }
    @db.execute("CREATE TABLE prices (id INTEGER PRIMARY KEY, amount REAL)")

    assert @db[:prices].create(amount: 0.5)
    assert @db[:prices].create(amount: '9.99')
    assert_raises(Dami::ValidationError) { @db[:prices].create(amount: 0.001) }
    assert_raises(Dami::ValidationError) { @db[:prices].create(amount: 10.5) }
    assert_raises(Dami::ValidationError) { @db[:prices].create(amount: 'abc') }
  end

  # --- Localization ----------------------------------------------------------

  def test_with_locale_is_thread_local
    Dami.locale = :en
    Dami.localize(:validations) { es { set :required, "es requerido" } }
    seen_by_other_thread = nil

    Dami.with_locale(:es) do
      seen_by_other_thread = Thread.new { Dami.current_locale }.value
      assert_equal :es, Dami.current_locale
      assert_equal "es requerido", Dami.translate("validations.required")
    end

    assert_equal :en, seen_by_other_thread, "another thread must not see the temporary locale"
    assert_equal :en, Dami.current_locale
  ensure
    Dami.locale = nil
  end

  # --- Migrations -------------------------------------------------------------

  def test_create_table_keeps_constraints
    migration = Dami::Migration.new(@db)
    migration.create_table(:accounts) do |t|
      t.field :id, :primary_key
      t.field :email, :string, null: false, unique: true
      t.field :balance, :decimal, default: 0
      t.field :owner_id, :integer, references: :users
      t.timestamps
    end
    migration.add_index(:accounts, :owner_id, unique: true)
    Dami.model(:accounts) do
      fields do
        field :email, :string
        field :balance, :decimal
        field :owner_id, :integer
        field :created_at, :datetime
        field :updated_at, :datetime
      end
    end

    columns = @db.execute("PRAGMA table_info(accounts)")
    assert_equal 'REAL', columns.find { |c| c['name'] == 'balance' }['type']
    assert_equal 'DATETIME', columns.find { |c| c['name'] == 'created_at' }['type']
    assert_equal 1, columns.find { |c| c['name'] == 'email' }['notnull']
    assert_equal '0', columns.find { |c| c['name'] == 'balance' }['dflt_value']

    owner = @db[:users].create(first_name: 'Owner', status: 'active')
    first = @db[:accounts].create(email: 'a@b.c', owner_id: owner[:id])
    assert_equal 0.0, first[:balance]
    refute_nil first[:created_at]

    assert_raises(Dami::UniqueConstraintViolation) { @db[:accounts].create(email: 'a@b.c', owner_id: owner[:id]) }
    assert_raises(Dami::NotNullViolation) { @db[:accounts].create(email: nil, owner_id: owner[:id]) }
    assert_raises(Dami::ForeignKeyViolation) { @db[:accounts].create(email: 'x@y.z', owner_id: 12_345) }
  end
end
