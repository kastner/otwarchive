require File.dirname(__FILE__) + '/../test_helper'

class RoleTest < Test::Unit::TestCase
  # Test associations
  def test_habtm_users
    user = create_user
    role = create_role
    assert role.users << user
    assert user.roles.include?(role)
  end
  # TODO belongs_to :authorizable
end
