class Material < ApplicationRecord
  belongs_to :user
  belongs_to :article, optional: true
  has_one_attached :file
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

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
  THUMBNAIL_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze

  validate :exactly_one_source
  validate :acceptable_file, if: -> { file.attached? }
  validates :published_precision, inclusion: { in: FuzzyDate::PRECISIONS }, allow_nil: true
  validate :published_columns_consistent
  validates :url, format: { with: %r{\Ahttps?://},
                            message: "は http(s) で始まる URL を指定してください" },
                  if: -> { url.present? }

  attr_accessor :tag_names, :published_year, :published_month, :published_day

  before_validation :assign_slug, on: :create
  validates :slug, presence: true, uniqueness: true

  def file? = file.attached?
  def link? = url.present?
  def published = FuzzyDate.wrap(published_at, published_precision)

  def thumbnailable_file?
    file.attached? && THUMBNAIL_TYPES.include?(file.content_type)
  end

  def thumbnail(px)
    file.representation(resize_to_limit: [px, px]) if thumbnailable_file?
  end

  def preview_image_url
    MaterialEmbed.thumbnail_src(url) if link?
  end

  def display_title
    return title if title.present?
    return file.filename.to_s if file.attached?
    url
  end

  private

  def published_columns_consistent
    return unless published_at.present? ^ published_precision.present?
    errors.add(:published_precision, "が必要です")
  end

  def assign_slug
    return if slug.present?
    self.slug = loop do
      candidate = Slug.token
      break candidate unless Material.exists?(slug: candidate)
    end
  end

  def exactly_one_source
    return if file.attached? ^ url.present?
    errors.add(:base, "ファイルかURLのどちらか一方を指定してください")
  end

  def acceptable_file
    errors.add(:file, "は対応していない形式です") unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
    errors.add(:file, "が大きすぎます") if file.byte_size.to_i > MAX_BYTES
  end
end
