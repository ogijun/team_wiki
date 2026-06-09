// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import LocalTime from "local-time"

// 相対タイムスタンプの日本語化。
// local_time の RelativeTime は elapsed テンプレートで全体を包むので、elapsed を "{time}"
// にして各単位語に「前」を畳み込む（10秒未満=たった今 / 1分前 / "2 分前" / 1時間前 /
// "3 時間前"）。数値と単位の間の半角スペースはライブラリ仕様。24時間超は昨日/曜日/日付へ。
LocalTime.config.i18n["ja"] = {
  date: {
    dayNames: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"],
    abbrDayNames: ["日", "月", "火", "水", "木", "金", "土"],
    monthNames: ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    abbrMonthNames: ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    yesterday: "昨日",
    today: "今日",
    tomorrow: "明日",
    on: "{date}",
    formats: { default: "%Y年%-m月%-d日", thisYear: "%-m月%-d日" }
  },
  time: {
    am: "午前",
    pm: "午後",
    singular: "{time}",
    singularAn: "{time}",
    elapsed: "{time}",
    second: "たった今",
    seconds: "秒前",
    minute: "1分前",
    minutes: "分前",
    hour: "1時間前",
    hours: "時間前",
    formats: { default: "%-H:%M", default_24h: "%-H:%M" }
  },
  datetime: {
    at: "{date} {time}",
    formats: { default: "%Y年%-m月%-d日 %-H:%M", default_24h: "%Y年%-m月%-d日 %-H:%M" }
  }
}
LocalTime.config.locale = "ja"
LocalTime.start()
document.addEventListener("turbo:morph", () => LocalTime.run())
