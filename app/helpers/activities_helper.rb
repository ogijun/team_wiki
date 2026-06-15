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
    label = activity_label(activity)
    return safe_join([ prefix, suffix ]) if label.blank?

    # 対象が存命ならタイトル自体をリンクに（末尾に同じタイトルを再掲しないため）。
    # 削除済み（subject が無い）ならプレーンテキスト。
    shown = activity.subject ? link_to(label, activity.subject) : label
    safe_join([ prefix, "「", shown, "」", suffix ])
  end

  # ── ActivityGrouper::Group の描画 ──

  # noun ごとの「作成/編集」まとめ表示の部品（prefix + 「label」 + before + 動詞 + after）。
  MERGE_NOUNS = {
    "article"       => { prefix: "が記事", before: "を",            after: "しました" },
    "transcription" => { prefix: "が",     before: "の文字起こしを", after: "しました" }
  }.freeze
  VERBS = { "created" => "作成", "edited" => "編集" }.freeze
  ACTION_LIST_HEAD = 2 # 同一操作まとめで常時表示する先頭件数

  def activity_group_icon(group)
    activity_icon(group.activities.first)
  end

  # actor: false で主語（先頭の「が」）を落とす（ユーザページ用）。
  def activity_group_phrase(group, actor: true)
    case group.kind
    when :subject then subject_group_phrase(group, actor: actor)
    when :action  then action_group_phrase(group, actor: actor)
    else activity_phrase(group.activities.first, actor: actor)
    end
  end

  private

  # 同一対象の作成/編集をまとめる: 「(が)記事「A」を作成・編集しました」。
  # 動詞は時系列（古い→新しい）順に重複除去して「・」連結。
  def subject_group_phrase(group, actor:)
    rep  = group.activities.first
    noun = rep.action.split(".").first
    spec = MERGE_NOUNS.fetch(noun)
    verbs = group.activities.reverse.map { |a| VERBS.fetch(a.action.split(".").last) }.uniq
    prefix = actor ? spec[:prefix] : spec[:prefix].delete_prefix("が")
    suffix = "#{spec[:before]}#{verbs.join('・')}#{spec[:after]}"
    safe_join([ prefix, "「", subject_link(rep), "」", suffix ])
  end

  # 同一操作で複数対象をまとめる: 「(が)資料「A」「B」ほか3件を追加しました」。
  # 対象は時系列（古い→新しい）順。先頭2件は常時表示、残りは隠して「ほかN件」で展開。
  def action_group_phrase(group, actor:)
    prefix, suffix = PHRASES.fetch(group.activities.first.action)
    prefix = prefix.delete_prefix("が") unless actor
    names = group.activities.reverse.map { |a| bracketed(subject_link(a)) }
    safe_join([ prefix, subject_list(names), suffix ])
  end

  def subject_list(names)
    return safe_join(names) if names.size <= ACTION_LIST_HEAD

    shown = names.first(ACTION_LIST_HEAD)
    rest  = names.drop(ACTION_LIST_HEAD)
    # 隠し名は「先頭2件」と suffix の「間」に置くので、展開しても語順が崩れない。
    tag.span(data: { controller: "disclosure" }) do
      safe_join([
        safe_join(shown),
        tag.button("ほか#{rest.size}件", type: "button", class: "timeline-more",
                   data: { action: "disclosure#toggle", "disclosure-target": "toggle" }),
        tag.span(safe_join(rest), hidden: true, data: { "disclosure-target": "rest" })
      ])
    end
  end

  def bracketed(inner)
    safe_join([ "「", inner, "」" ])
  end

  # 対象が存命ならタイトルをリンクに、削除済み（subject nil）なら素テキスト。
  def subject_link(activity)
    label = activity_label(activity)
    activity.subject ? link_to(label, activity.subject) : label
  end

  # タイムラインの表示名。対象が存命ならその現在の title/name を引く
  # （URL資料の非同期タイトル取得など、記録後に名前が変わるケースに自動追従）。
  # 削除済みは記録時の subject_label（墓標）にフォールバック。
  def activity_label(activity)
    subject = activity.subject
    return activity.subject_label unless subject
    (subject.try(:title) || subject.try(:name)).presence || activity.subject_label
  end
end
