require "test_helper"

class PageRevisionCreatorTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "c@example.com", password: "password123", name: "C") }

  def create_page(title)
    Page.create!(title: title, created_by: @user)
  end

  test "creates revision and sets current_revision" do
    page = create_page("Doc")
    rev = PageRevisionCreator.call(page: page, body: "本文", author: @user)
    assert_equal rev, page.reload.current_revision
    assert_equal "本文", page.current_revision.body
  end

  test "rebuilds outgoing links resolving existing targets" do
    target = create_page("ターゲット")
    PageRevisionCreator.call(page: target, body: "x", author: @user)
    page = create_page("Src")
    PageRevisionCreator.call(page: page, body: "[[ターゲット]] と [[未作成]]", author: @user)

    links = page.reload.outgoing_links.order(:target_title)
    resolved = links.find { |l| l.target_title == "ターゲット" }
    broken = links.find { |l| l.target_title == "未作成" }
    assert_equal target.id, resolved.target_page_id
    assert_nil broken.target_page_id
  end

  test "syncs tags from names" do
    page = create_page("Tagged")
    PageRevisionCreator.call(page: page, body: "x", author: @user, tag_names: ["ruby", "rails"])
    assert_equal %w[rails ruby], page.reload.tags.pluck(:name).sort
  end

  test "removes tags no longer present on next save" do
    page = create_page("Retag")
    PageRevisionCreator.call(page: page, body: "x", author: @user, tag_names: ["a", "b"])
    PageRevisionCreator.call(page: page, body: "x", author: @user, tag_names: ["a"])
    assert_equal ["a"], page.reload.tags.pluck(:name)
  end

  test "backfills inbound broken links when target page is created" do
    src = create_page("Linker")
    PageRevisionCreator.call(page: src, body: "[[あとで作る]]", author: @user)
    assert_nil src.outgoing_links.first.target_page_id

    later = create_page("あとで作る")
    PageRevisionCreator.call(page: later, body: "本文", author: @user)

    assert_equal later.id, src.outgoing_links.first.reload.target_page_id
  end
end
