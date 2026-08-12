# URL クエリだけを入力に資料一覧のフィルタを組み立てる。状態は保存しない。
class MaterialFilter
  AppliedFilter = Data.define(:label, :value, :value_tag, :suffix, :clear_params)

  DEFINITIONS = {
    "q" => {
      valid: ->(params) { params["q"].present? },
      apply: ->(scope, params) {
        scope.where("materials.title LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params["q"])}%")
      },
      notice: ->(params) { [ "キーワード", params["q"], :code, "で絞り込み中" ] }
    },
    "kind" => {
      valid: ->(params) { Material::KINDS.key?(params["kind"]) },
      apply: ->(scope, params) { scope.where(kind: params["kind"]) },
      notice: ->(params) { [ "種別:", Material::KINDS[params["kind"]], nil, nil ] }
    },
    "transcription_status" => {
      valid: ->(params) { Material::TRANSCRIPTION_STATUS_SCOPES.key?(params["transcription_status"]) },
      apply: ->(scope, params) { scope.public_send(Material::TRANSCRIPTION_STATUS_SCOPES[params["transcription_status"]]) },
      notice: ->(params) { [ "文字起こし:", Material::TRANSCRIPTION_STATUS_LABELS[params["transcription_status"]], nil, nil ] }
    }
  }.freeze

  def self.apply(scope, params)
    DEFINITIONS.reduce(scope) do |filtered, (key, definition)|
      definition[:valid].call(params) ? definition[:apply].call(filtered, params) : filtered
    end
  end

  def self.applied(params)
    DEFINITIONS.filter_map do |key, definition|
      next unless definition[:valid].call(params)

      label, value, value_tag, suffix = definition[:notice].call(params)
      AppliedFilter.new(label, value, value_tag, suffix, params.except(key, "page"))
    end
  end
end
