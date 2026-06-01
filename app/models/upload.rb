class Upload < ApplicationRecord
  belongs_to :user
  has_one_attached :file

  ALLOWED = %w[image/png image/jpeg image/gif image/webp video/mp4 video/webm].freeze
  MAX_BYTES = 50.megabytes

  validate :acceptable_file

  private

  def acceptable_file
    return errors.add(:file, "が必要です") unless file.attached?
    errors.add(:file, "は対応していない形式です") unless ALLOWED.include?(file.content_type)
    errors.add(:file, "が大きすぎます") if file.byte_size.to_i > MAX_BYTES
  end
end
