class Material < ApplicationRecord
  belongs_to :user
  belongs_to :article, optional: true
  has_one_attached :file
  has_one :transcription, dependent: :destroy
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
  CONFIDENCE_LEVELS = { "confirmed" => "原本確認済", "unconfirmed" => "未確認" }.freeze
  RIGHTS_STATUSES = { "quotable" => "引用可", "private" => "全文非公開", "caution" => "要注意" }.freeze
  TRANSCRIBABLE_KINDS = %i[image video audio document].freeze

  validate :exactly_one_source
  validate :acceptable_file, if: -> { file.attached? }
  validates :published_precision, inclusion: { in: FuzzyDate::PRECISIONS }, allow_nil: true
  validate :published_columns_consistent
  validates :url, format: { with: %r{\Ahttps?://},
                            message: "は http(s) で始まる URL を指定してください" },
                  if: -> { url.present? }
  validates :confidence, inclusion: { in: CONFIDENCE_LEVELS.keys }
  validates :rights, inclusion: { in: RIGHTS_STATUSES.keys }, allow_nil: true

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

  # メディア種別を symbol で返す（表示の絵文字対応はビュー層に置く）。
  def media_kind
    return :link if link?
    case file.content_type.to_s.split("/").first
    when "image" then :image
    when "video" then :video
    when "audio" then :audio
    else :document
    end
  end

  def transcribable? = TRANSCRIBABLE_KINDS.include?(media_kind)

  def display_title
    return title if title.present?
    return file.filename.to_s if file.attached?
    url
  end

  def confidence_label = CONFIDENCE_LEVELS[confidence]
  def rights_label = rights ? RIGHTS_STATUSES[rights] : "未設定"

  private

  def published_columns_consistent
    return unless published_at.present? ^ published_precision.present?
    errors.add(:published_precision, "が必要です")
  end

  def assign_slug
    self.slug ||= Slug.unique_token { |c| Material.exists?(slug: c) }
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
