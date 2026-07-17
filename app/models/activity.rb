class Activity < ApplicationRecord
  ACTIONS = %w[
    article.created article.edited article.deleted
    material.added material.deleted
    comment.posted
    transcription.created transcription.edited transcription.assigned
    tag.created tag.deleted
    publication.registered publication.edited publication.deleted
    user.joined
  ].freeze
  CREATION_ACTIONS = %w[article.created material.added comment.posted transcription.created].freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true
  has_many :likes, as: :reactable, dependent: :destroy

  validates :action, presence: true, inclusion: { in: ACTIONS }

  def liked_by?(user) = user.present? && likes.exists?(reactor: user)

  # 作成系は成果物と同じ Like を共有し、編集等の行いは Activity 自身を対象にする。
  def like_target = (CREATION_ACTIONS.include?(action) && subject) ? subject : self

  # 活動を記録する。subject_label 未指定なら subject の title/name から導出する
  # （subject が消えても一覧に名前を残すための非正規化フィールド）。
  def self.record(actor:, action:, subject: nil, subject_label: nil)
    create!(
      user: actor,
      action: action,
      subject: subject,
      subject_label: subject_label || default_label(subject)
    )
  end

  def self.default_label(subject)
    return nil if subject.nil?
    return subject.title if subject.respond_to?(:title)
    return subject.name  if subject.respond_to?(:name)
    nil
  end
  private_class_method :default_label
end
