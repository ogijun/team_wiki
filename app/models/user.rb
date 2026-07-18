class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy
  has_one_attached :avatar

  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  AVATAR_MAX_BYTES = 5.megabytes

  # 担当(assignee)ピッカー等の「メンバー一覧」用。アバター prefetch ＋ 名前順（単一の出所）。
  scope :for_picker, -> { with_attached_avatar.order(:name) }

  attr_accessor :current_password

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  # 1行プロフィール。任意で、公開プロフィールとメンバー一覧に表示する。
  validates :bio, length: { maximum: 100 }
  validates :role, inclusion: { in: %w[editor admin] }
  validate :acceptable_avatar, if: -> { avatar.attached? }

  def admin? = role == "admin"

  # プロフィールに出す貢献カウント（作成した記事・書いた版・関わった文字起こし）。
  def contribution_stats
    {
      articles_created: Article.where(created_by: self).count,
      revisions_authored: Revision.where(author: self).count,
      transcriptions_contributed: TranscriptionRevision.where(author: self).distinct.count(:transcription_id)
    }
  end

  # 自分が作成・投稿した成果物と自身の活動行に付いた Like の合計。
  def received_likes_count
    Like.where(reactable_type: "Article", reactable_id: Article.where(created_by: self).select(:id)).count +
      Like.where(reactable_type: "Material", reactable_id: Material.where(user: self).select(:id)).count +
      Like.where(reactable_type: "Comment", reactable_id: Comment.where(author: self).select(:id)).count +
      Like.where(reactable_type: "Transcription", reactable_id: Transcription.where(author: self).select(:id)).count +
      Like.where(reactable_type: "Publication", reactable_id: Publication.where(registered_by: self).select(:id)).count +
      Like.where(reactable_type: "Activity", reactable_id: Activity.where(user: self).select(:id)).count
  end

  # 活動日（JST）から { current_streak:, longest_streak:, active_days: } を算出する。
  # current_streak は「今日 or 昨日まで連続」している日数（今日まだ活動が無くても昨日までの連続は生存）。
  def activity_stats(today: Date.current)
    dates = Activity.where(user: self).pluck(:created_at).map { |t| t.in_time_zone.to_date }.uniq.sort
    return { current_streak: 0, longest_streak: 0, active_days: 0 } if dates.empty?

    runs = dates.slice_when { |a, b| b != a + 1 }.to_a
    last_run = runs.last
    current = (last_run.last == today || last_run.last == today - 1) ? last_run.size : 0
    { current_streak: current, longest_streak: runs.map(&:size).max, active_days: dates.size }
  end

  private

  def acceptable_avatar
    errors.add(:avatar, "は画像にしてください") unless AVATAR_CONTENT_TYPES.include?(avatar.content_type)
    errors.add(:avatar, "が大きすぎます") if avatar.byte_size.to_i > AVATAR_MAX_BYTES
  end
end
