require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include AuthTestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]

  # ログイン画面から「Discord でログイン」を押す。OmniAuth はテストモードなので
  # Discord には行かず、ギルドのロール確認だけ差し替える。
  def sign_in_through_ui(user)
    mock_discord_auth(user.uid, name: user.name, email: user.email_address)
    role = Rails.configuration.x.discord.required_role_ids.first
    stub_membership(DiscordGuildMembership::Result.new(true, [ role ])) do
      visit new_session_path
      click_on "Discord でログイン"
      assert_selector "summary[aria-label='ユーザーメニューを開く']"
    end
  end

  # 右上のアバターを押して、ユーザーメニュー (名前・設定・ログアウト) を開く。
  def open_user_menu
    find("summary[aria-label='ユーザーメニューを開く']").click
  end

  # toast-ui エディタ (WYSIWYG) に打ち込む。元の textarea は隠されていて、
  # 保存時にエディタの中身が書き戻される。
  def fill_in_editor(text)
    editor = find(".toastui-editor-ww-container [contenteditable=true]")
    editor.click
    editor.send_keys([ :command, "a" ], :backspace) unless editor.text.empty?
    editor.send_keys(text)
  end
end
