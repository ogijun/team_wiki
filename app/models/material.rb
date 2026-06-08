class Material < ApplicationRecord
  include FuzzyDateAttributable
  include Taggable

  belongs_to :user
  belongs_to :article, optional: true
  has_one_attached :file
  has_one :transcription, dependent: :destroy

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

  fuzzy_date_attribute :published_at

  validates :published_precision, inclusion: { in: FuzzyDate::PRECISIONS }, allow_nil: true
  validates :url, format: { with: %r{\Ahttps?://\S+\z},
                            message: "は http(s) で始まる URL を指定してください" },
                  if: -> { url.present? }
  validates :confidence, inclusion: { in: CONFIDENCE_LEVELS.keys }
  # フォームの「未設定」(include_blank) は "" を送る。空文字は nil 扱いにして allow_nil を効かせる。
  normalizes :rights, with: ->(v) { v.presence }
  validates :rights, inclusion: { in: RIGHTS_STATUSES.keys }, allow_nil: true

  before_validation :assign_slug, on: :create
  before_validation :ensure_title, on: :create
  validates :slug, presence: true, uniqueness: true
  validates :title, presence: true

  def file? = file.attached?
  def link? = url.present?

  def thumbnailable_file?
    file.attached? && THUMBNAIL_TYPES.include?(file.content_type)
  end

  def thumbnail(px)
    file.representation(resize_to_limit: [ px, px ]) if thumbnailable_file?
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

  def confidence_label = CONFIDENCE_LEVELS[confidence]
  def rights_label = rights ? RIGHTS_STATUSES[rights] : "未設定"

  private

  def assign_slug
    self.slug ||= Slug.unique_token { |c| Material.exists?(slug: c) }
  end

  # 作成時、title 未記入なら url かファイル名（拡張子抜き）で必ず埋める（HTTP は行わない）。
  # コントローラはこれより先に oEmbed/og:title でより良い title を入れるので、ここは最終保険。
  def ensure_title
    return if title.present?
    self.title = url.presence || attached_basename
  end

  def attached_basename
    return unless file.attached?
    file.filename.base.presence || file.filename.to_s
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
