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

  test "create makes a new tag" do
    assert_difference("Tag.count", 1) do
      post tags_url, params: { tag: { name: "rails" } }
    end
    assert_redirected_to tags_url
    assert Tag.exists?(name: "rails")
  end

  test "create with blank name re-renders index" do
    assert_no_difference("Tag.count") do
      post tags_url, params: { tag: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "create requires login" do
    delete session_url
    assert_no_difference("Tag.count") do
      post tags_url, params: { tag: { name: "golang" } }
    end
    assert_redirected_to new_session_url
  end

  test "destroy removes a tag with no pages" do
    empty = Tag.create!(name: "unused")
    assert_difference("Tag.count", -1) do
      delete tag_url(empty)
    end
    assert_redirected_to tags_url
    assert_not Tag.exists?(empty.id)
  end

  test "destroy refuses a tag that has pages" do
    assert_no_difference("Tag.count") do
      delete tag_url(@tag)
    end
    assert Tag.exists?(@tag.id)
  end

  test "destroy requires login" do
    empty = Tag.create!(name: "unused")
    delete session_url
    assert_no_difference("Tag.count") do
      delete tag_url(empty)
    end
    assert_redirected_to new_session_url
  end
end
