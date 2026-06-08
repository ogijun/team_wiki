# 可変精度の日付（<col>_at / <col>_precision の2列）を、フォーム入力用の
# 仮想アクセサ（<acc>_year/_month/_day/_hour/_minute）から組み立てるための concern。
#
#   fuzzy_date_attribute :published_at              # 列=published_at, アクセサ=published_*
#   fuzzy_date_attribute :starts_at, accessor: :start  # 列=starts_at, アクセサ=start_*, メソッド=starts
#
# 生成物: 仮想アクセサ群 / before_validation で parts→列へ詰める / precision 整合バリデーション /
#         FuzzyDate を返すラッパーメソッド <col>。
module FuzzyDateAttributable
  extend ActiveSupport::Concern

  class_methods do
    def fuzzy_date_attribute(column, accessor: nil)
      col = column.to_s.delete_suffix("_at") # "published" / "starts"
      acc = (accessor || col).to_s           # "published" / "start"
      parts = %w[year month day hour minute]

      attr_accessor(*parts.map { |p| :"#{acc}_#{p}" })

      validate :"#{col}_columns_consistent"
      before_validation :"assign_#{col}_from_parts"

      define_method(col) { FuzzyDate.wrap(send("#{col}_at"), send("#{col}_precision")) }

      define_method(:"#{col}_columns_consistent") do
        at = send("#{col}_at")
        precision = send("#{col}_precision")
        errors.add("#{col}_precision", "が必要です") if at.present? ^ precision.present?
      end

      define_method(:"assign_#{col}_from_parts") do
        values = parts.map { |p| send("#{acc}_#{p}") }
        # 仮想アクセサが一つも代入されていない（全 nil）save では触らない＝既存値を保つ。
        # フォーム経由は空欄でも "" が入る（≠nil）ので、全空欄なら nil 代入＝クリアできる。
        return if values.all?(&:nil?)

        fd = FuzzyDate.from_parts(
          year: values[0], month: values[1], day: values[2], hour: values[3], minute: values[4]
        )
        send("#{col}_at=", fd&.at)
        send("#{col}_precision=", fd&.precision)
      end
    end
  end
end
