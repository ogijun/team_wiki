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

  MEDIA_ICONS = { link: "link", image: "image", video: "film", audio: "music", document: "file-text" }.freeze

  # Material#media_kind をアイコンに対応づける（表示の単一窓口）。
  def media_icon(material)
    icon(MEDIA_ICONS.fetch(material.media_kind))
  end

  # 一覧などで使う書き起こし状況ラベル。対象外（リンク等）は nil。
  # 対象メディアで未作成なら「未着手」、ありなら作業中/完了。
  def transcription_status_label(material)
    return nil unless material.transcribable?
    { "todo" => "未着手", "drafting" => "作業中", "done" => "完了" }[material.transcription_status]
  end

  # 資料詳細の進行ストリップ。資料のライフサイクル
  # （書誌→文字起こし→原本確認→引用）を「済み=チェック / 未=次の行動リンク」で1行に出す。
  # 各要素: { text:, done:, path:(未完の行動先。nil ならプレーン表示) }
  def material_progress_steps(material)
    steps = []
    steps << if material.bibliography_present?
      { text: "書誌", done: true }
    else
      { text: "書誌を追記", done: false, path: edit_material_path(material) }
    end

    if material.transcribable?
      done, total = material.transcription_progress
      steps << if total.positive? && material.transcription_status == "done"
        { text: "文字起こし", done: true }
      else
        label = total.positive? ? "文字起こし #{done}/#{total}" : "文字起こし 未着手"
        { text: label, done: false, path: new_material_transcription_path(material) }
      end
    end

    steps << if material.confidence == "confirmed"
      { text: "原本確認済", done: true }
    else
      # 信頼度の確定は admin のみ操作できるため、editor にはテキストで状態だけ示す
      { text: "原本未確認", done: false,
        path: Current.user&.admin? ? edit_material_path(material) : nil }
    end

    count = material.citing_articles.count
    steps << if count.positive?
      { text: "引用 #{count}件", done: true }
    else
      { text: "引用タグを使う", done: false, path: "#usage" }
    end
    steps
  end
end
