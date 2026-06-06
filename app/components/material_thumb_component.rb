# 資料のサムネを出し分ける部品: 画像ファイル→variant / YouTube→サムネ画像 / それ以外→種別アイコン。
class MaterialThumbComponent < ViewComponent::Base
  def initialize(material:)
    @material = material
  end
end
