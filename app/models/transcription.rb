class Transcription < ApplicationRecord
  STATUSES = { "drafting" => "作業中", "done" => "完了" }.freeze

  belongs_to :material
  belongs_to :author, class_name: "User"

  validates :body, presence: true
  validates :status, inclusion: { in: STATUSES.keys }
  validates :material_id, uniqueness: true

  def status_label = STATUSES[status]
end
