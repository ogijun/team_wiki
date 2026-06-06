# 資料の書誌情報から脚注の体裁を組み立てる。埋まっている項目だけを連結し、
# タイトル部分のみリンクにする（純粋な文字列組み立てなので call で描画）。
class CitationComponent < ViewComponent::Base
  def initialize(material:)
    @material = material
  end

  def call
    segments = []
    segments << "#{lead}. " if lead.present?
    segments << helpers.link_to(@material.display_title, @material)
    safe_join(segments)
  end

  private

  def lead
    @lead ||= begin
      s = +""
      s << @material.author if @material.author.present?
      s << "『#{@material.source}』" if @material.source.present?
      s << "(#{@material.published_at.year})" if @material.published_at.present?
      s
    end
  end
end
