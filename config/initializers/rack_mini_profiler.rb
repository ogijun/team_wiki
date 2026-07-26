# 開発時のみ、ページ左上に応答時間と SQL を出す。
# バッジをクリックすると内訳（各クエリの時間・発行元）が開くので、N+1 や重いクエリを
# 「体感」ではなく数字で見つけられる。
#
# 使い方:
#   ?pp=help          利用できるモードの一覧
#   ?pp=disable       一時的に無効化
#   ?pp=flamegraph    フレームグラフ（要 stackprof）
return unless Rails.env.development?

# PDF や画像の配信はプロファイル対象にしない（バイナリ応答にバッジは差し込めず、
# Range 取得のたびに記録が増えて逆にノイズになる）。資料の一覧・詳細ページ自体は
# 計測したいので、PDF 配信エンドポイントだけを正規表現で狙う。
Rack::MiniProfiler.config.skip_paths += [ %r{\A/materials/\d+/pdf}, "/rails/active_storage" ]
