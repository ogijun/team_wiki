# 資料のサムネを出し分ける部品: 画像ファイル→variant / YouTube→サムネ画像 / それ以外→種別アイコン。
class MaterialThumbComponent < ViewComponent::Base
  def initialize(material:, px: 48)
    @material = material
    @px = px
  end

  private

  def type_icon
    return "🔗" if @material.link?
    case @material.file.content_type.to_s.split("/").first
    when "image" then "🖼"
    when "video" then "🎬"
    when "audio" then "🎵"
    else "📄"
    end
  end
end
