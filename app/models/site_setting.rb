# サイト全体の設定（単一行）。ブランド名・ロゴ・アプリアイコン（正方形）を持つ。
class SiteSetting < ApplicationRecord
  # SVG は除外（直リンクで開いた際のスクリプト実行＝stored XSS 余地のため）。ラスタ画像のみ許可。
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  IMAGE_MAX_BYTES = 5.megabytes

  has_one_attached :logo
  has_one_attached :icon # 正方形画像。favicon / apple-touch-icon を variant 生成する元。
  # 空欄送信は nil に寄せる（ホームのヒーローは present? で出し分けるため、空白だけの値で出さない）。
  normalizes :tagline, with: ->(v) { v.presence }
  validate :acceptable_logo, if: -> { logo.attached? }
  validate :acceptable_icon, if: -> { icon.attached? }

  def self.instance
    first_or_create!
  end

  private

  def acceptable_logo
    errors.add(:logo, "は画像にしてください") unless IMAGE_CONTENT_TYPES.include?(logo.content_type)
    errors.add(:logo, "が大きすぎます") if logo.byte_size.to_i > IMAGE_MAX_BYTES
  end

  def acceptable_icon
    errors.add(:icon, "は画像にしてください") unless IMAGE_CONTENT_TYPES.include?(icon.content_type)
    errors.add(:icon, "が大きすぎます") if icon.byte_size.to_i > IMAGE_MAX_BYTES
  end
end
