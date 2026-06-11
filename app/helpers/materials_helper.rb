module MaterialsHelper
  # ソート可能なテーブル見出しを作る。クリックで asc/desc トグル、現在列に矢印。
  def sortable(column, label)
    current = params[:sort].to_s == column
    current_dir = params[:dir] == "asc" ? "asc" : "desc"
    next_dir = (current && current_dir == "asc") ? "desc" : "asc"
    arrow = current ? (current_dir == "asc" ? " ▲" : " ▼") : ""
    link_to "#{label}#{arrow}",
            materials_path(request.query_parameters.merge(sort: column, dir: next_dir, page: nil)),
            class: "sort-link"
  end

  MEDIA_ICONS = { link: "🔗", image: "🖼", video: "🎬", audio: "🎵", document: "📄" }.freeze

  # Material#media_kind を絵文字に対応づける（表示の単一窓口）。
  def media_icon(material)
    MEDIA_ICONS.fetch(material.media_kind)
  end

  # 一覧などで使う書き起こし状況ラベル。対象外（リンク等）は nil。
  # 対象メディアで未作成なら「未着手」、ありなら作業中/完了。
  def transcription_status_label(material)
    return nil unless material.transcribable?
    material.transcription&.status_label || "未着手"
  end

  # 資料詳細の進行ストリップ。資料のライフサイクル
  # （書誌→文字起こし→原本確認→引用）を「済み=✓ / 未=次の行動リンク」で1行に出す。
  # 各要素: { text:, done:, path:(未完の行動先。nil ならプレーン表示) }
  def material_progress_steps(material)
    steps = []
    steps << if material.bibliography_present?
      { text: "書誌 ✓", done: true }
    else
      { text: "書誌を追記", done: false, path: edit_material_path(material) }
    end

    if material.transcribable?
      t = material.transcription
      steps << if t&.status == "done"
        { text: "文字起こし ✓", done: true }
      else
        { text: "文字起こし #{t ? t.status_label : "未着手"}", done: false,
          path: edit_material_transcription_path(material) }
      end
    end

    steps << if material.confidence == "confirmed"
      { text: "原本確認済 ✓", done: true }
    else
      # 信頼度の確定は admin のみ操作できるため、editor にはテキストで状態だけ示す
      { text: "原本未確認", done: false,
        path: Current.user&.admin? ? edit_material_path(material) : nil }
    end

    count = material.citing_articles.count
    steps << if count.positive?
      { text: "引用 #{count}件 ✓", done: true }
    else
      { text: "引用タグを使う", done: false, path: "#usage" }
    end
    steps
  end
end
