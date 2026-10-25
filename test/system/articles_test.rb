require "application_system_test_case"

class ArticlesTest < ApplicationSystemTestCase
  setup do
    @user = create(:user)
    sign_in_through_ui(@user)
  end

  test "記事を作ると、本文つきで表示される" do
    visit new_article_path
    fill_in "タイトル", with: "システムテストの記事"
    fill_in_editor "エディタから入れた本文"
    submit_form

    assert_text "記事を作成しました。"
    assert_selector "h1", text: "システムテストの記事"
    assert_text "エディタから入れた本文"
  end

  test "記事を編集すると、変えた内容で表示される" do
    article = Article.create_with_revision!({ title: "編集前のタイトル", created_by: @user }, body: "編集前の本文", author: @user)
    visit article_path(article)
    click_on "本文を編集"

    fill_in "タイトル", with: "編集後のタイトル"
    fill_in_editor "編集後の本文"
    submit_form

    assert_text "記事を保存しました。"
    assert_selector "h1", text: "編集後のタイトル"
    assert_text "編集後の本文"
    assert_no_text "編集前の本文"
  end

  private

  def submit_form = find("form.stacked-form input[type=submit]").click
end
