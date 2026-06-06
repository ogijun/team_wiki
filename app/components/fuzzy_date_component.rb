# あいまい日付（FuzzyDate）を表示する部品。単体・期間（starts〜ends）の両方に対応。
# starts が無ければ何も描画しない。icon: true でカレンダー絵文字を前置する。
class FuzzyDateComponent < ViewComponent::Base
  def initialize(starts:, ends: nil, icon: false)
    @starts = starts
    @ends = ends
    @icon = icon
  end

  def render?
    @starts.present?
  end
end
