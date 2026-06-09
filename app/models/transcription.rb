class Transcription < ApplicationRecord
  STATUSES = { "drafting" => "作業中", "done" => "完了" }.freeze
  CREATION_METHODS = {
    "manual" => "手書き（聞き取り）",
    "ai" => "AI",
    "ai_assisted" => "AI下書き＋人手修正"
  }.freeze
  AI_METHODS = %w[ai ai_assisted].freeze

  belongs_to :material
  belongs_to :author, class_name: "User"

  normalizes :creation_method, :ai_service, :ai_model, with: ->(v) { v.presence }

  validates :body, presence: true
  validates :status, inclusion: { in: STATUSES.keys }
  validates :creation_method, inclusion: { in: CREATION_METHODS.keys }, allow_nil: true
  validates :material_id, uniqueness: true

  # 手書き等で AI 情報が残らないようにする（状態の整合性を保つ）。
  before_validation { self.ai_service = self.ai_model = nil unless ai? }

  def status_label = STATUSES[status]

  def ai? = AI_METHODS.include?(creation_method)

  # 「AI（OpenAI / whisper-large-v3）」のような表示用文字列。未記録は nil。
  def creation_summary
    return nil if creation_method.blank?
    label = CREATION_METHODS[creation_method]
    return label unless ai?
    parts = [ ai_service, ai_model ].compact_blank
    parts.any? ? "#{label}（#{parts.join(" / ")}）" : label
  end
end
