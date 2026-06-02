module ActivitiesHelper
  # action -> [接頭文言, 接尾文言]。label がある場合は 接頭 + 「label」 + 接尾。
  PHRASES = {
    "page.created"     => ["がページ", "を作成しました"],
    "page.edited"      => ["がページ", "を編集しました"],
    "page.deleted"     => ["がページ", "を削除しました"],
    "material.added"   => ["が資料", "を追加しました"],
    "material.deleted" => ["が資料", "を削除しました"],
    "tag.created"      => ["がタグ", "を作成しました"],
    "tag.deleted"      => ["がタグ", "を削除しました"],
    "user.joined"      => ["", "が参加しました"]
  }.freeze

  def activity_phrase(activity)
    prefix, suffix = PHRASES.fetch(activity.action, ["", "が操作しました"])
    label = activity.subject_label
    if label.present?
      "#{prefix}「#{label}」#{suffix}"
    else
      "#{prefix}#{suffix}"
    end
  end
end
