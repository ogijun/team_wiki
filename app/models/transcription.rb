class Transcription < ApplicationRecord
  include Reactable

  STATUSES = { "drafting" => "作業中", "done" => "完了" }.freeze
  CREATION_METHODS = {
    "manual" => "手書き（聞き取り）",
    "ai" => "AI",
    "ai_assisted" => "AI下書き＋人手修正"
  }.freeze
  AI_METHODS = %w[ai ai_assisted].freeze
  # 資料詳細ページに出すプレビューの上限行数。超過分は専用ページ（show）へ誘導する。
  PREVIEW_LINES = 20

  belongs_to :material
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :author, class_name: "User"
  has_many :revisions, class_name: "TranscriptionRevision", dependent: :destroy

  normalizes :creation_method, :ai_service, :ai_model, with: ->(v) { v.presence }

  validates :body, presence: true
  validates :status, inclusion: { in: STATUSES.keys }
  validates :creation_method, inclusion: { in: CREATION_METHODS.keys }, allow_nil: true
  validates :label, length: { maximum: 120 }, allow_blank: true

  # 手書き等で AI 情報が残らないようにする（状態の整合性を保つ）。
  before_validation { self.ai_service = self.ai_model = nil unless ai? }

  def status_label = STATUSES[status]

  # 表示状態は (assignee, status) から導出する（新カラムは持たない）。
  ASSIGNMENT_STATE_LABELS = { done: "完了", in_progress: "担当中", unassigned: "担当者募集中" }.freeze

  def assignment_state
    return :done if status == "done"
    assignee_id.present? ? :in_progress : :unassigned
  end

  def assignment_state_label = ASSIGNMENT_STATE_LABELS[assignment_state]

  def display_label = label.presence || "パート#{position}"

  # 認可述語（自作。詳細は [[project-authorization-approach]]）。現状はメンバーなら誰でも編集可。
  # 将来は割り当てワークフロー（assignee 中心＋admin）に絞る想定＝ここを変える唯一の窓口。
  def editable_by?(user) = user.present?

  # 担当(assignee)の設定/変更/解除は誰でも自由（GitHub の assignee と同じ。編集ゲートにはしない）。
  def assignable_by?(user) = user.present?

  def ai? = AI_METHODS.include?(creation_method)

  # 版の author を初参加順（最初に貢献した順）で重複除去して返す（Article#contributors と同形）。
  def contributors
    ids = revisions.order(:created_at).pluck(:author_id).uniq
    by_id = User.where(id: ids).with_attached_avatar.index_by(&:id)
    ids.map { |id| by_id[id] }
  end

  def long? = body.to_s.lines.size > PREVIEW_LINES
  def preview_body = body.to_s.lines.first(PREVIEW_LINES).join
  def overflow_lines = [ body.to_s.lines.size - PREVIEW_LINES, 0 ].max

  # 「AI（OpenAI / whisper-large-v3）」のような表示用文字列。未記録は nil。
  def creation_summary
    return nil if creation_method.blank?
    label = CREATION_METHODS[creation_method]
    return label unless ai?
    parts = [ ai_service, ai_model ].compact_blank
    parts.any? ? "#{label}（#{parts.join(" / ")}）" : label
  end
end
