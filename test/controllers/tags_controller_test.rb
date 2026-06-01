require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "tg@example.com", password: "password123", name: "TG")
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @page = Page.create!(title: "Tagged", created_by: @user)
    PageRevisionCreator.call(page: @page, body: "x", author: @user, tag_names: ["ruby"])
    @tag = Tag.find_by(name: "ruby")
  end

  test "show lists pages with the tag" do
    get tag_url(@tag)
    assert_response :success
    assert_select "a", text: "Tagged"
  end

  test "index lists all tags" do
    get tags_url
    assert_response :success
    assert_select "a", text: /ruby/
  end
end
