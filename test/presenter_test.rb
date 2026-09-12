# File: test/presenter_test.rb

require_relative 'test_helper'

class PresenterTest < Minitest::Test
  def setup
    super
    
    Dami.model :users do
      fields do
        field :first_name, :string
        field :last_name, :string
        field :status, :string
      end
    end
    
    Dami.present :users do
      def full_name
        "#{self[:first_name]} #{self[:last_name]}"
      end
      
      def status
        "Status: #{self[:status].capitalize}"
      end
    end
    
    @user = @db[:users].create(first_name: 'Alice', last_name: 'Smith', status: 'active')
  end
  
  def test_presenter_method_overrides_field_access
    assert_equal "Status: Active", @user.status
    assert_equal "active", @user[:status]
  end
  
  def test_method_access_falls_back_to_field_if_not_defined
    assert_equal "Alice", @user.first_name
  end

  def test_custom_presenter_methods_work_as_expected
    assert_equal "Alice Smith", @user.full_name
  end
  
  def test_calling_nonexistent_method_or_field_raises_error
    assert_raises(NoMethodError) do
      @user.nonexistent_attribute
    end
  end
end