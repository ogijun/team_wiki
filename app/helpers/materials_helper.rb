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
end
