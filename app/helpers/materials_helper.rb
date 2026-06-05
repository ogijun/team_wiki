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

  # 資料の書誌情報から脚注用の体裁を組み立てる純粋ヘルパー。
  # 埋まっている項目だけを連結し、タイトル部分のみリンクにする。
  def citation_text(material)
    lead = +""
    lead << material.author if material.author.present?
    lead << "『#{material.source}』" if material.source.present?
    lead << "(#{material.published_at.year})" if material.published_at.present?

    segments = []
    segments << "#{lead}. " if lead.present?
    segments << link_to(material.display_title, material)
    if material.link? && material.retrieved_on.present?
      segments << " ［取得: #{material.retrieved_on.iso8601}］"
    end
    safe_join(segments)
  end
end
