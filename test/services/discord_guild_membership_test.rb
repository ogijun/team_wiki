require "test_helper"

class DiscordGuildMembershipTest < ActiveSupport::TestCase
  test "parses member roles from a successful response" do
    fake = Struct.new(:code, :body).new("200", { "roles" => [ "r1", "r2" ] }.to_json)
    result = DiscordGuildMembership.from_response(fake)
    assert_predicate result, :member?
    assert_equal [ "r1", "r2" ], result.role_ids
  end

  test "non-member (404) yields member? false" do
    fake = Struct.new(:code, :body).new("404", "")
    result = DiscordGuildMembership.from_response(fake)
    assert_not result.member?
    assert_empty result.role_ids
  end
end
