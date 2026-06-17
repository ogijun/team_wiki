class Material < ApplicationRecord
  include FuzzyDateAttributable
  include Taggable

  belongs_to :user
  has_one_attached :file
  # パート分割: 1資料に複数の文字起こしパート。position 昇順。
  has_many :transcriptions, -> { order(:position) }, dependent: :destroy
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
  # 実物の所持状況（nil=未設定）。出典検証の confidence と違い、所持は事実なので編集は誰でも可。
  OWNERSHIP_STATUSES = { "original" => "原本所有", "partial" => "部分所有", "none" => "未所持（データのみ）" }.freeze

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
  normalizes :ownership, with: ->(v) { v.presence }
  validates :ownership, inclusion: { in: OWNERSHIP_STATUSES.keys }, allow_nil: true

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
  def pdf? = file.attached? && file.content_type == "application/pdf"

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
  # total_pages = page_count の合計 ＋ page_count 未設定の画像の枚数（画像1枚=1ページ）。
  # page_count を持つ画像は SUM 側で数えるので画像枚数からは除く（二重計上を防ぐ）。
  def self.library_summary
    kinds = kind_counts
    files = ActiveStorage::Attachment.where(record_type: "Material", name: "file")
    images_without_pages = where(page_count: nil).joins(file_attachment: :blob)
                             .where("active_storage_blobs.content_type LIKE ?", "image/%").count
    {
      file_count: files.count,
      total_bytes: files.joins(:blob).sum("active_storage_blobs.byte_size"),
      total_pages: sum(:page_count).to_i + images_without_pages,
      kind_counts: kinds
    }
  end

  # 移行後の一括補完用。page_count 未設定の PDF を抽出して埋める（冪等）。
  def self.backfill_page_counts!
    updated = 0
    with_attached_file.where(page_count: nil).find_each do |m|
      next unless m.pdf?
      result = MaterialMetadataExtractor.call(m)
      next unless result[:page_count]
      m.update_column(:page_count, result[:page_count])
      updated += 1
    end
    updated
  end

  # PDF を linearize（Web表示用に最適化・可逆）して blob を最適化版へ差し替える。冪等。
  # has_one_attached の再 attach は旧 blob を purge_later で削除する（オーファンは出ない）。
  # 失敗（暗号化・破損・qpdf不在）は原本据え置き＋ログ。アップロードは既に成功しているので raise しない。
  def linearize_file!
    return unless pdf?

    out = nil
    file.open { |tmp| out = PdfLinearizer.linearize(tmp.path) unless PdfLinearizer.linearized?(tmp.path) }
    return unless out

    File.open(out) { |f| file.attach(io: f, filename: file.filename.to_s, content_type: "application/pdf") }
  rescue StandardError => e
    Rails.logger.warn("linearize_file! failed for Material##{id}: #{e.class}: #{e.message}")
  ensure
    File.unlink(out) if out && File.exist?(out)
  end

  # すべての資料を文字起こし対象とする（ファイル/URL を問わず）。
  def transcribable? = true

  # 書誌情報がひとつでも入っているか（進行ストリップと書誌ゾーンの表示判定）。
  def bibliography_present?
    author.present? || source.present? || published_at.present? ||
      volume.present? || publisher.present? || pages.present? || isbn.present? || page_count.present?
  end

  def confidence_label = CONFIDENCE_LEVELS[confidence]
  def rights_label = rights ? RIGHTS_STATUSES[rights] : "未設定"
  def ownership_label = ownership ? OWNERSHIP_STATUSES[ownership] : nil

  # ── 認可述語（自作。モデルに `*_able_by?(user)` を置く方針。規則が増えたら Pundit へ。詳細は
  #    [[project-authorization-approach]]）。Comment#deletable_by? と同じ書き味で揃える。──
  # 現状: メタデータ編集・削除はログイン済みメンバーなら誰でも可（wiki 的）。将来絞るならここを変える。
  def editable_by?(user) = user.present?
  def deletable_by?(user) = user.present?
  # 信頼度（原本検証の確定）は admin のみ。インスタンス状態に依存しない役割判定。
  def confidence_editable_by?(user) = user&.admin? || false

  # パート集約: 0件=todo / 全完了=done / それ以外=drafting。
  def transcription_status
    parts = transcriptions.to_a
    return "todo" if parts.empty?
    parts.all? { |t| t.status == "done" } ? "done" : "drafting"
  end

  # 表示用 [完了数, 総数]。
  def transcription_progress
    parts = transcriptions.to_a
    [ parts.count { |t| t.status == "done" }, parts.size ]
  end

  private

  def assign_slug
    self.slug ||= Slug.unique_token { |c| Material.exists?(slug: c) }
  end

  # 作成時、title 未記入なら url かファイル名（拡張子抜き）で必ず埋める（HTTP は行わない）。
  # 後処理ジョブが後から oEmbed/og:title でより良い title に上書きするので、ここは即時の保険。
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
