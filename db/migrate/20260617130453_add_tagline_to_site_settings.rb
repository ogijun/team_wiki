class AddTaglineToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    # ホームのヒーローに出すミッション/タグライン一言（ブランド固有文言は設定で注入＝コード中立を保つ）。
    add_column :site_settings, :tagline, :string
  end
end
