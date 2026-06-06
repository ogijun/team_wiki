# 丸ピル型のバッジ。variant でアクセント(:status)・種別(:kind)・既定(:default) を出し分ける。
class BadgeComponent < ViewComponent::Base
  def initialize(text:, variant: :default)
    @text = text
    @variant = variant
  end
end
