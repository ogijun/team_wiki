require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "tg@example.com", name: "TG", provider: "discord", uid: "tag-user")
    sign_in_as(@user)
    @article = Article.create!(title: "Tagged", created_by: @user)
    @article.tag_names = "ruby"
    @article.revise!(body: "x", author: @user)
    @tag = Tag.find_by(name: "ruby")
  end

  test "show lists materials with the tag (materials-first)" do
    material = Material.new(user: @user, title: "タグ付き資料")
    material.tag_names = "ruby"
    material.file.attach(io: StringIO.new("x"), filename: "m.mp3", content_type: "audio/mpeg")
    material.save!

    get tag_url(@tag)
    assert_response :success
    assert_select "a", text: "タグ付き資料"
  end

  test "show still lists articles with the tag" do
    get tag_url(@tag)
    assert_response :success
    assert_select "a", text: "Tagged"
  end

  test "show explains the empty case when nothing carries the tag" do
    empty = Tag.create!(name: "empty-tag")
    get tag_url(empty)
    assert_response :success
    assert_select ".empty-state"
  end

  test "empty tag links to a body search using the tag name as the query" do
    empty = Tag.create!(name: "未使用タグ")
    get tag_url(empty)
    assert_response :success
    assert_select ".empty-state a[href=?]", search_path(q: "未使用タグ")
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

  test "destroy removes a tag with no articles" do
    empty = Tag.create!(name: "unused")
    assert_difference("Tag.count", -1) do
      delete tag_url(empty)
    end
    assert_redirected_to tags_url
    assert_not Tag.exists?(empty.id)
  end

  test "destroy refuses a tag that has articles" do
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

  test "create records tag.created activity" do
    assert_difference("Activity.where(action: 'tag.created').count", 1) do
      post tags_url, params: { tag: { name: "rec-tag" } }
    end
  end

  test "destroy records tag.deleted activity only when actually deleted" do
    empty = Tag.create!(name: "unused-rec")
    assert_difference("Activity.where(action: 'tag.deleted').count", 1) do
      delete tag_url(empty)
    end
    assert_equal "unused-rec", Activity.where(action: "tag.deleted").order(:id).last.subject_label

    # ページを持つタグは削除されない → 記録もされない
    assert_no_difference("Activity.where(action: 'tag.deleted').count") do
      delete tag_url(@tag)
    end
  end
end
