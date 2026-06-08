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

  private

  def acceptable_avatar
    errors.add(:avatar, "は画像にしてください") unless AVATAR_CONTENT_TYPES.include?(avatar.content_type)
    errors.add(:avatar, "が大きすぎます") if avatar.byte_size.to_i > AVATAR_MAX_BYTES
  end
end
