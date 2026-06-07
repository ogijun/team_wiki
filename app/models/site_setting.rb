# サイト全体の設定（単一行）。ブランド名と任意のロゴ画像を持つ。
class SiteSetting < ApplicationRecord
  # SVG は除外（直リンクで開いた際のスクリプト実行＝stored XSS 余地のため）。ラスタ画像のみ許可。
  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  LOGO_MAX_BYTES = 5.megabytes

  has_one_attached :logo
  validate :acceptable_logo, if: -> { logo.attached? }

  def self.instance
    first_or_create!
  end

  private

  def acceptable_logo
    errors.add(:logo, "は画像にしてください") unless LOGO_CONTENT_TYPES.include?(logo.content_type)
    errors.add(:logo, "が大きすぎます") if logo.byte_size.to_i > LOGO_MAX_BYTES
  end
end
