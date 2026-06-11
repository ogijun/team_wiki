class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_one_attached :avatar

  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  AVATAR_MAX_BYTES = 5.megabytes

  attr_accessor :current_password

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :role, inclusion: { in: %w[editor admin] }
  validate :acceptable_avatar, if: -> { avatar.attached? }

  def admin? = role == "admin"

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
