class Material < ApplicationRecord
  include FuzzyDateAttributable
  include Taggable

  belongs_to :user
  has_one_attached :file
  has_one :transcription, dependent: :destroy
  has_many :citations, dependent: :nullify
  has_many :citing_articles, -> { distinct }, through: :citations, source: :article
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :activities, as: :subject, dependent: :nullify

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
  # 1ファイルの上限。本番は R2（容量無制限）＋ kamal-proxy の既定 max_request_body=1GB に合わせる。
  # これを 1GB 超にするなら deploy.yml の proxy.buffering.max_request_body も上げること。
  MAX_BYTES = 1.gigabyte
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

  # 書誌の詳細（すべて任意・自由記述）。空文字は nil に揃える。
  normalizes :isbn, :pages, :publisher, :volume, with: ->(v) { v.presence }
  # ISBN は新旧・ハイフン有無の表記揺れを許容する緩い検証（数字・ハイフン・空白・チェック桁の X のみ）。
  validates :isbn, format: { with: /\A[\d\-xX ]+\z/, message: "は数字・ハイフン・X のみで入力してください" }, allow_nil: true

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

  # content_type → メディア種別 symbol の対応（表示・集計が共有する単一の出どころ）。
  def self.kind_for(content_type)
    case content_type.to_s.split("/").first
    when "image" then :image
    when "video" then :video
    when "audio" then :audio
    else :document
    end
  end

  # メディア種別を symbol で返す（表示の絵文字対応はビュー層に置く）。
  def media_kind
    return :link if link?
    self.class.kind_for(file.content_type)
  end

  # 種別ごとの件数（画像/動画/音声/文書/リンク）。リンクは url 有無、ファイルは blob の content_type で判定。
  # 27件規模では grouped count で十分。500件超で media_kind をカラム化する（WHEN-IT-HURTS 閾値）。
  def self.kind_counts
    counts = Hash.new(0)
    counts[:link] = where.not(url: [ nil, "" ]).count
    ActiveStorage::Attachment.where(record_type: "Material", name: "file")
                             .joins(:blob)
                             .group("active_storage_blobs.content_type").count
                             .each { |content_type, n| counts[kind_for(content_type)] += n }
    counts
  end

  # 資料コレクションの現在値の単一窓口。一覧ヘッダ帯と StatSnapshot.current_values が共用する。
  # total_pages = PDF のページ数合計（SUM page_count）＋ 画像件数（画像1枚=1ページ）。
  def self.library_summary
    kinds = kind_counts
    files = ActiveStorage::Attachment.where(record_type: "Material", name: "file")
    {
      file_count: files.count,
      total_bytes: files.joins(:blob).sum("active_storage_blobs.byte_size"),
      total_pages: sum(:page_count).to_i + kinds[:image],
      kind_counts: kinds
    }
  end

  def transcribable? = TRANSCRIBABLE_KINDS.include?(media_kind)

  # 書誌情報がひとつでも入っているか（進行ストリップと書誌ゾーンの表示判定）。
  def bibliography_present?
    author.present? || source.present? || published_at.present? ||
      volume.present? || publisher.present? || pages.present? || isbn.present?
  end

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
