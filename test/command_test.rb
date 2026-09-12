# # frozen_string_literal: true
# require_relative 'test_helper'
#  class ComposedCommand < Dami::Command
#     validate :value_is_positive, error: "Value must be positive" do
#       data[:value].to_i > 0
#     end
#   end
#   class ConditionalCommand < Dami::Command
#     requires_context :is_admin
#     compose ComposedCommand # Test composition
#     validate :name_must_be_admin, error: "Name must be 'admin'", if: -> { is_admin } do
#       data[:name] == 'admin'
#     end
#     validate :name_must_not_be_admin, error: "Name cannot be 'admin'", unless: -> { is_admin } do
#       data[:name] != 'admin'
#     end
#   end
# class ActionsTest < Minitest::Test
#   module TestPolicies
#     NORMALIZE_NAME = ->(command_class) do
#       command_class.transform(:normalize_name) { |data| data[:name] = data[:name].strip; data }
#     end
#   end
#   class TestCommand < Dami::Command
#     requires_context :multiplier
#     apply TestPolicies::NORMALIZE_NAME
#     validate :name_is_present, error: "Name is required" do
#       !data[:name].to_s.empty?
#     end
#     transform :capitalize_name do |data|
#       data[:name] = data[:name].capitalize
#       data
#     end
#     transform :apply_multiplier do |data|
#       data[:value] = data[:value] * multiplier
#       data
#     end
#   end
#   def test_command_succeeds_with_valid_data
#     command = TestCommand.new(
#       original: {},
#       data: { name: '  test  ', value: 10 },
#       context: { multiplier: 3 }
#     ).call
#     assert command.valid?
#     assert_equal "Test", command.data[:name]
#     assert_equal 30, command.data[:value]
#   end
#   def test_command_fails_with_invalid_data
#     command = TestCommand.new(
#       original: {},
#       data: { name: '', value: 10 },
#       context: { multiplier: 3 }
#     ).call
#     refute command.valid?
#     assert_equal({ name_is_present: ["Name is required"] }, command.errors)
#   end
#   def test_command_fails_if_context_is_missing
#     assert_raises(ArgumentError) do
#       TestCommand.new(original: {}, data: { name: 'test', value: 10 })
#     end
#   end
# end