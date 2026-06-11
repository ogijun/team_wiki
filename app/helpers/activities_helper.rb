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

  def activity_phrase(activity)
    prefix, suffix = PHRASES.fetch(activity.action, [ "", "が操作しました" ])
    label = activity.subject_label
    return safe_join([ prefix, suffix ]) if label.blank?

    # 対象が存命ならタイトル自体をリンクに（末尾に同じタイトルを再掲しないため）。
    # 削除済み（subject が無い）ならプレーンテキスト。
    shown = activity.subject ? link_to(label, activity.subject) : label
    safe_join([ prefix, "「", shown, "」", suffix ])
  end
end
