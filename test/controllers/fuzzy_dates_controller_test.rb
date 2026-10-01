require "test_helper"

class FuzzyDatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(email_address: "fd@example.com", name: "FD", provider: "discord", uid: "fuzzy-date")
    sign_in_as(user)
  end

  test "returns the parsed label or unreadable marker" do
    travel_to Time.zone.local(2026, 9, 25) do
      { "1979/4" => "1979年4月", "昨日" => "2026年9月24日", "" => "", "あした" => "読めない" }.each do |text, label|
        get fuzzy_date_url(text: text)
        assert_response :success
        assert_equal label, response.body
      end
    end
  end
end
