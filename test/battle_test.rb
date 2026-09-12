require_relative 'test_helper'

# --- Test Class 1: High-Concurrency & Transaction Integrity ---

class ConcurrencyBattleTest < Minitest::Test
  def setup
    super
    @db.execute("CREATE TABLE accounts (id INTEGER PRIMARY KEY, name TEXT, balance INTEGER);")
    Dami.model(:accounts) { fields { field :name, :string; field :balance, :integer } }
  end

  def test_bank_transfer_under_contention_maintains_data_integrity
    account_a = @db[:accounts].create(name: 'A', balance: 10000)
    account_b = @db[:accounts].create(name: 'B', balance: 10000)
    initial_total_balance = account_a[:balance] + account_b[:balance]
    
    threads = 20.times.map do
      Thread.new do
        # --- THE FIX IS HERE ---
        # Add a retry mechanism to handle SQLite's busy exceptions.
        retries = 0
        begin
          @db.transaction do
            a = @db[:accounts].find(account_a[:id])
            b = @db[:accounts].find(account_b[:id])
            
            sleep(rand * 0.005)

            @db[:accounts].where(id: a[:id]).update(balance: a[:balance] - 10)
            @db[:accounts].where(id: b[:id]).update(balance: b[:balance] + 10)
          end
        rescue SQLite3::BusyException
          retries += 1
          raise if retries > 10 # Give up after 10 retries
          sleep(rand * 0.05)    # Wait a bit longer before retrying
          retry
        end
        # --- END FIX ---
      end
    end
    
    threads.each(&:join)
    
    final_a = @db[:accounts].find(account_a[:id])
    final_b = @db[:accounts].find(account_b[:id])
    final_total_balance = final_a[:balance] + final_b[:balance]

    assert_equal initial_total_balance, final_total_balance, "Total balance must remain constant"
    assert_equal 10000 - (20 * 10), final_a[:balance], "Account A balance should be correctly debited"
    assert_equal 10000 + (20 * 10), final_b[:balance], "Account B balance should be correctly credited"
  end
end


# --- Test Class 2: Advanced Association Patterns ---
class AssociationBattleTest < Minitest::Test
  def setup
    super
    # Create a schema for a self-referential relationship (e.g., Employee -> Manager)
    @db.execute("CREATE TABLE employees (id INTEGER PRIMARY KEY, name TEXT, manager_id INTEGER);")
    
    Dami.model :employees do
      fields { field :name, :string; field :manager_id, :integer }
      relationships do
        # THE FIX IS HERE: Removed the hyphen before :manager
        belongs_to :manager, model: :employees, foreign_key: :manager_id
        has_many :reports, model: :employees, foreign_key: :manager_id
      end
    end
  end
  
  def test_self_referential_associations_work_correctly
    ceo = @db[:employees].create(name: 'CEO')
    manager = @db[:employees].create(name: 'Manager', manager_id: ceo[:id])
    dev = @db[:employees].create(name: 'Developer', manager_id: manager[:id])
    
    # --- Test Lazy Loading ---
    assert_equal 'Manager', dev.manager[:name], "Lazy loading 'belongs_to' failed"
    assert_equal 'CEO', dev.manager.manager[:name], "Chained lazy loading failed"
    assert_equal ['Developer'], manager.reports.map { |r| r[:name] }, "Lazy loading 'has_many' failed"
    
    # --- Test Preloading ---
    employees = @db[:employees].preload(:manager, :reports).to_a
    
    loaded_manager = employees.find { |e| e[:name] == 'Manager' }
    loaded_dev = employees.find { |e| e[:name] == 'Developer' }
    
    # Check that preloaded data is correct
    assert_equal 'CEO', loaded_manager.manager[:name]
    assert_equal ['Developer'], loaded_manager.reports.map { |r| r[:name] }
    assert_equal 'Manager', loaded_dev.manager[:name]
    assert_equal [], loaded_dev.reports, "An employee with no reports should have an empty preloaded array"
  end
end

# --- Test Class 3: Database Constraint Violations ---

# Define the custom exception we expect the ORM to eventually raise.
# This allows the test to be written before the feature is implemented.
module Dami
  class UniqueConstraintViolation < StandardError; end unless const_defined?(:UniqueConstraintViolation)
end

class ConstraintBattleTest < Minitest::Test
  def setup
    super
    @db.execute("CREATE TABLE products (id INTEGER PRIMARY KEY, sku TEXT UNIQUE NOT NULL);")
    Dami.model :products do
      fields { field :sku, :string }
    end
  end
  def test_creating_duplicate_raises_specific_exception
    @db[:products].create(sku: 'ABC123')
    error = assert_raises(Dami::UniqueConstraintViolation) do
      @db[:products].create(sku: 'ABC123')
    end
    assert_includes error.message, "UNIQUE constraint failed"
    assert_equal :sku, error.column
  end
end