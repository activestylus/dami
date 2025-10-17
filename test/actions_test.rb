# frozen_string_literal: true
require_relative 'test_helper'

# Define a custom error class for testing retry logic
class ApiError < StandardError; end

module TestPolicies
  NORMALIZE_NAME = ->(command_class) do
    command_class.transform(:normalize_name) { |data| { name: data[:name].strip } }
  end
end
class TestCommand < Dami::Command
  requires_context :multiplier
  apply TestPolicies::NORMALIZE_NAME # Apply the policy

  validate :name_is_present, error: "Name is required" do
    !data[:name].to_s.empty?
  end
  transform :capitalize_name do |data|
    { name: data[:name].capitalize }
  end
  transform :apply_multiplier do |data|
    { value: data[:value] * multiplier } if data.key?(:value)
  end
end
class ActionsTest < Minitest::Test
  def setup
    super # This is CRITICAL. It connects to the DB and creates the schema.

    # Clear definitions to prevent pollution from other tests.
    ObjectSpace.each_object(Class).select { |c| c < Dami::Command }.each(&:clear_definitions!)

    # Re-apply DSL for TestCommand after clear.
    TestCommand.requires_context :multiplier
    TestCommand.apply TestPolicies::NORMALIZE_NAME
    TestCommand.validate :name_is_present, error: "Name is required" do
      !data[:name].to_s.empty?
    end
    TestCommand.transform :capitalize_name do |data|
      { name: data[:name].capitalize }
    end
    TestCommand.transform :apply_multiplier do |data|
      { value: data[:value] * multiplier } if data.key?(:value)
    end

    # Re-apply DSL for CreateUserCommand after clear.
    CreateUserCommand.validate :name_is_present, error: "Name is required" do
      !data[:name].to_s.empty?
    end
    CreateUserCommand.transform :normalize_email do |data|
      { email: data[:email].downcase }
    end
  end



  def test_command_succeeds_with_valid_data
    command = TestCommand.new(
      original: {},
      data: { name: '  test  ', value: 10 },
      context: { multiplier: 3 }
    ).call

    assert command.valid?
    assert_equal "Test", command.data[:name] # Should be stripped then capitalized.
    assert_equal 30, command.data[:value]
  end

  def test_command_fails_with_invalid_data
    command = TestCommand.new(
      original: {},
      data: { name: '', value: 10 },
      context: { multiplier: 3 }
    ).call
    refute command.valid?
    assert_equal({ name_is_present: ["Name is required"] }, command.errors)
  end

  def test_command_fails_if_context_is_missing
    assert_raises(ArgumentError, "Missing required context: multiplier") do
      TestCommand.new(original: {}, data: { name: 'test' }, context: {})
    end
  end

  class CreateUserCommand < Dami::Command
    validate :name_is_present, error: "Name is required" do
      !data[:name].to_s.empty?
    end
    transform :normalize_email do |data|
      { email: data[:email].downcase }
    end
  end

  def test_flow_succeeds_and_runs_hooks
    side_effect_run = false
    Dami.flow :create_user do
      clean_data = prepare CreateUserCommand, with: params
      user = db(:users).create(clean_data)
      succeed with: user, and_then: -> { side_effect_run = true }
    end

    result = Dami.run(:create_user, params: { name: 'Flow User', email: 'FLOW@TEST.COM', status: 'active' })
    
    assert result.success?
    assert_equal 'Flow User', result.value[:name]
    assert_equal 'flow@test.com', result.value[:email]
    assert_equal true, side_effect_run
    assert_equal 1, @db[:users].where(name: 'Flow User').count
  end

  def test_flow_halts_on_prepare_failure
    side_effect_run = false
    Dami.flow :create_user_fail do
      clean_data = prepare CreateUserCommand, with: params
      db(:users).create(clean_data)
      succeed with: {}, and_then: -> { side_effect_run = true }
    end

    result = Dami.run(:create_user_fail, params: { name: '', email: 'fail@test.com' })

    refute result.success?
    assert_equal({ name_is_present: ["Name is required"] }, result.error)
    assert_equal false, side_effect_run
    assert_equal 0, @db[:users].count
  end

  def test_flow_rolls_back_on_exception
    side_effect_run = false
    Dami.flow :failing_flow do
      db(:users).create(name: 'Should be rolled back', email: 'test@test.com', status: 'active')
      perform("External API") { raise "API Failure" }
      succeed with: {}, and_then: -> { side_effect_run = true }
    end

    assert_raises(RuntimeError, "API Failure") do
      Dami.run(:failing_flow)
    end

    assert_equal false, side_effect_run
    assert_equal 0, @db[:users].count
  end


  # --- NEW RESILIENCE TESTS ---

  def test_perform_retries_on_failure_and_succeeds
    call_count = 0
    Dami.flow :retry_success_flow do
      db(:users).create(name: 'Resilient User', email: 'retry@test.com', status: 'active')
      # THE FIX IS HERE: Use retry_options:
      perform("Flaky API", retry_options: { on: [ApiError], times: 2 }) do
        call_count += 1
        raise ApiError if call_count == 1
        "Success on attempt #{call_count}"
      end
      succeed with: {}
    end

    result = Dami.run(:retry_success_flow)
    assert result.success?, "Flow should succeed after retry"
    assert_equal 2, call_count, "The block should have been called twice"
    assert_equal 1, @db[:users].count, "User record should be committed"
  end

  def test_perform_exhausts_retries_and_fails
    call_count = 0
    Dami.flow :retry_failure_flow do
      db(:users).create(name: 'Should be rolled back', email: 'fail@test.com', status: 'active')
      # THE FIX IS HERE: Use retry_options:
      perform("Consistently Failing API", retry_options: { on: [ApiError], times: 2 }) do
        call_count += 1
        raise ApiError, "API is down"
      end
      succeed with: {} # This should not be reached
    end

    assert_raises(ApiError) { Dami.run(:retry_failure_flow) }
    assert_equal 3, call_count, "The block should have been attempted 3 times"
    assert_equal 0, @db[:users].count, "Database should be rolled back on final failure"
  end

  def test_perform_fails_on_timeout
    Dami.flow :timeout_flow do
      db(:users).create(name: 'Should be rolled back', email: 'timeout@test.com', status: 'active')
      perform("Slow API", timeout: 0.01) do
        sleep 0.02
      end
      succeed with: {}
    end

    assert_raises(Timeout::Error) { Dami.run(:timeout_flow) }
    assert_equal 0, @db[:users].count, "Database should be rolled back on timeout"
  end
end