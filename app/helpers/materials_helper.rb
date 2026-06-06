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

  # 資料のサムネ（画像 variant / YouTube サムネ / 種別アイコン）を出し分ける。
  def material_thumb(material, px: 48)
    if material.thumbnailable_file?
      image_tag material.thumbnail(px), class: "material-thumb", loading: "lazy", alt: material.display_title
    elsif (src = material.preview_image_url)
      image_tag src, class: "material-thumb", loading: "lazy", alt: material.display_title
    else
      content_tag :span, material_type_icon(material), class: "material-thumb material-thumb--icon", title: material.display_title
    end
  end

  def material_type_icon(material)
    return "🔗" if material.link?
    case material.file.content_type.to_s.split("/").first
    when "image" then "🖼"
    when "video" then "🎬"
    when "audio" then "🎵"
    else "📄"
    end
  end
end
