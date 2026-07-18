class Notification < ApplicationRecord
  KINDS = %w[like comment assignment].freeze

  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User"
  belongs_to :subject, polymorphic: true

  validates :kind, inclusion: { in: KINDS }

  # 全 feeder の単一入口。自己宛は通知を作らない。
  def self.emit(recipient:, actor:, kind:, subject:)
    return if recipient == actor

    create!(recipient: recipient, actor: actor, kind: kind, subject: subject)
  end
end
