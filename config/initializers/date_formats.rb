# 日本式の日付・日時フォーマット。表示は to_fs(:jp) で統一する。
Date::DATE_FORMATS[:jp] = "%Y年%-m月%-d日"            # 2026年6月7日
Time::DATE_FORMATS[:jp] = "%Y年%-m月%-d日 %H:%M"       # 2026年6月7日 18:30
# シンプル版（スラッシュ表記）。一覧の日時など控えめに出したいとき。
Time::DATE_FORMATS[:simple] = "%Y/%m/%d %H:%M"        # 2026/06/07 18:30
