class Material < ApplicationRecord
  belongs_to :user
  belongs_to :page, optional: true
  has_one_attached :file

  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    image/png image/jpeg image/gif image/webp
    video/mp4 video/webm
    audio/mpeg audio/wav audio/mp4 audio/ogg
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    text/csv text/plain
    application/zip
  ].freeze
  MAX_BYTES = 100.megabytes

  validate :exactly_one_source
  validate :acceptable_file, if: -> { file.attached? }
  validates :url, format: { with: %r{\Ahttps?://},
                            message: "は http(s) で始まる URL を指定してください" },
                  if: -> { url.present? }

  def file? = file.attached?
  def link? = url.present?

  private

  def exactly_one_source
    return if file.attached? ^ url.present?
    errors.add(:base, "ファイルかURLのどちらか一方を指定してください")
  end

  def acceptable_file
    errors.add(:file, "は対応していない形式です") unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
    errors.add(:file, "が大きすぎます") if file.byte_size.to_i > MAX_BYTES
  end
end
