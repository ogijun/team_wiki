class Notification < ApplicationRecord
  KINDS = %w[like comment assignment].freeze

  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User"
  belongs_to :subject, polymorphic: true

  validates :kind, inclusion: { in: KINDS }

  # 全 feeder の単一入口。自己宛は通知を作らない。
  def self.emit(recipient:, actor:, kind:, subject:)
    return if recipient == actor

    unread = where(recipient: recipient, actor: actor, kind: kind, subject: subject)
      .where("created_at > ?", recipient.notifications_seen_at || recipient.created_at)
      .order(:created_at)
      .first
    return unread.touch if unread

    create!(recipient: recipient, actor: actor, kind: kind, subject: subject)
  end

  def self.owner_for(subject)
    case subject
    when Article then subject.created_by
    when Material then subject.user
    when Comment then subject.author
    when Transcription then subject.author
    when Publication then subject.registered_by
    when Activity then subject.user
    end
  end
end
