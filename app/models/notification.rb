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

  # デプロイ後にコンソールから手動実行する、未読通知の既存重複整理。
  def self.dedupe_unread!
    recipients = User.where.not(notifications_seen_at: nil).or(User.where.not(created_at: nil))
    recipients.find_each do |recipient|
      threshold = recipient.notifications_seen_at || recipient.created_at
      where(recipient: recipient).where("created_at > ?", threshold)
        .group(:actor_id, :kind, :subject_type, :subject_id).having("COUNT(*) > 1")
        .pluck(:actor_id, :kind, :subject_type, :subject_id).each do |actor_id, kind, subject_type, subject_id|
          duplicates = where(recipient: recipient, actor_id: actor_id, kind: kind, subject_type: subject_type, subject_id: subject_id).where("created_at > ?", threshold).order(:created_at)
          keep = duplicates.first
          newest_updated_at = duplicates.maximum(:updated_at)
          duplicates.where.not(id: keep.id).delete_all
          keep.update_column(:updated_at, newest_updated_at)
        end
    end
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
