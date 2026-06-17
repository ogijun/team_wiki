class AddHomeHeadingToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    # トップページの大見出し(h1)。ブランド固有の文言はコードに埋め込まず設定で注入する。
    # 未設定なら home 側は文書構造用の sr-only 見出しにフォールバックする。
    add_column :site_settings, :home_heading, :string
  end
end
