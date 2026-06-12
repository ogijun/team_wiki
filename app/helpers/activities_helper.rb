module ActivitiesHelper
  # action -> [接頭文言, 接尾文言]。label がある場合は 接頭 + 「label」 + 接尾。
  PHRASES = {
    "article.created"  => [ "が記事", "を作成しました" ],
    "article.edited"   => [ "が記事", "を編集しました" ],
    "article.deleted"  => [ "が記事", "を削除しました" ],
    "material.added"   => [ "が資料", "を追加しました" ],
    "material.deleted" => [ "が資料", "を削除しました" ],
    "comment.posted"   => [ "が", "にコメントしました" ],
    "transcription.created" => [ "が", "の文字起こしを作成しました" ],
    "transcription.edited"  => [ "が", "の文字起こしを編集しました" ],
    "tag.created"      => [ "がタグ", "を作成しました" ],
    "tag.deleted"      => [ "がタグ", "を削除しました" ],
    "user.joined"      => [ "", "が参加しました" ]
  }.freeze

  # action -> タイムラインの行頭アイコン（スプライトの symbol 名）。
  ICONS = {
    "article.created"  => "newspaper",
    "article.edited"   => "pencil-line",
    "article.deleted"  => "trash-2",
    "material.added"   => "landmark",
    "material.deleted" => "trash-2",
    "comment.posted"   => "message-circle",
    "transcription.created" => "audio-lines",
    "transcription.edited"  => "pen-line",
    "tag.created"      => "tags",
    "tag.deleted"      => "trash-2",
    "user.joined"      => "users"
  }.freeze

  def activity_icon(activity)
    icon(ICONS.fetch(activity.action, "info"), css: "timeline__icon")
  end

  # actor: false で主語（先頭の「が」）を落とす。ユーザページなど actor が自明な文脈用。
  def activity_phrase(activity, actor: true)
    prefix, suffix = PHRASES.fetch(activity.action, [ "", "が操作しました" ])
    unless actor
      prefix = prefix.delete_prefix("が")
      suffix = suffix.delete_prefix("が") if prefix.empty?
    end
    label = activity.subject_label
    return safe_join([ prefix, suffix ]) if label.blank?

    # 対象が存命ならタイトル自体をリンクに（末尾に同じタイトルを再掲しないため）。
    # 削除済み（subject が無い）ならプレーンテキスト。
    shown = activity.subject ? link_to(label, activity.subject) : label
    safe_join([ prefix, "「", shown, "」", suffix ])
  end
end
