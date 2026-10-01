# 資料の書誌情報から脚注の体裁を組み立てる。埋まっている項目だけを連結し、
# タイトル部分のみリンクにする（純粋な文字列組み立てなので call で描画）。
class CitationComponent < ViewComponent::Base
  def initialize(material:)
    @material = material
  end

  def call
    segments = []
    segments << "#{lead}. " if lead.present?
    segments << helpers.link_to(@material.title, @material)
    safe_join(segments)
  end

  private

  def lead
    [
      (@material.author if @material.author.present?),
      ("『#{@material.source}』" if @material.source.present?),
      ("(#{FuzzyTimestamp.parts(@material.published)[:year]})" if @material.published.present?)
    ].compact.join
  end
end
