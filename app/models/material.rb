class Material < ApplicationRecord
  include FuzzyDateAttributable
  include Taggable

  belongs_to :user
  has_one_attached :file
  has_one_attached :web_file
  # パート分割: 1資料に複数の文字起こしパート。position 昇順。
  has_many :transcriptions, -> { order(:position) }, dependent: :destroy
  has_many :citations, dependent: :nullify
  has_many :citing_articles, -> { distinct }, through: :citations, source: :article
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :reactable, dependent: :destroy
  has_many :notifications, as: :subject, dependent: :destroy
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
  RIGHTS_STATUSES = { "quotable" => "引用可", "private" => "全文非公開", "caution" => "要注意" }.freeze
  # 実物の所持状況（nil=未設定）。出典検証の confidence と違い、所持は事実なので編集は誰でも可。
  OWNERSHIP_STATUSES = { "original" => "原本所有", "partial" => "部分所有", "none" => "未所持（データのみ）" }.freeze
  # ユーザが選べる「分類（資料種類）」。保存はフラットな単一 enum（nil=自動判定にフォールバック）。
  KINDS = {
    "video" => "動画", "audio" => "音声", "image" => "画像",
    "book" => "書籍", "magazine" => "雑誌記事", "pamphlet" => "パンフレット",
    "newspaper" => "新聞", "setting" => "設定資料",
    "web" => "Webページ", "other" => "その他"
  }.freeze
  # 選択UI: 映像/音声/画像は1段目で直接、残りは大分類でグルーピング（2段階）。保存値はフラット。
  KIND_TOP = %w[video audio image].freeze
  KIND_GROUPS = {
    "出版物・文書" => %w[book magazine pamphlet newspaper setting],
    "Web・その他"  => %w[web other]
  }.freeze

  validate :exactly_one_source
  validate :acceptable_file, if: -> { file.attached? }

  fuzzy_date_attribute :published_at

  validates :published_precision, inclusion: { in: FuzzyDate::PRECISIONS }, allow_nil: true
  validates :url, format: { with: %r{\Ahttps?://\S+\z},
                            message: "は http(s) で始まる URL を指定してください" },
                  if: -> { url.present? }
  # フォームの「未設定」(include_blank) は "" を送る。空文字は nil 扱いにして allow_nil を効かせる。
  normalizes :rights, with: ->(v) { v.presence }
  validates :rights, inclusion: { in: RIGHTS_STATUSES.keys }, allow_nil: true
  normalizes :ownership, with: ->(v) { v.presence }
  validates :ownership, inclusion: { in: OWNERSHIP_STATUSES.keys }, allow_nil: true
  normalizes :kind, with: ->(v) { v.presence }
  validates :kind, inclusion: { in: KINDS.keys }, allow_nil: true

  # 書誌の詳細（すべて任意・自由記述）。空文字は nil に揃える。
  normalizes :isbn, :pages, :publisher, :volume, with: ->(v) { v.presence }
  # ISBN は新旧・ハイフン有無の表記揺れを許容する緩い検証（数字・ハイフン・空白・チェック桁の X のみ）。
  validates :isbn, format: { with: /\A[\d\-xX ]+\z/, message: "は数字・ハイフン・X のみで入力してください" }, allow_nil: true

  before_validation :assign_slug, on: :create
  before_validation :ensure_title, on: :create
  # 未選択(自動判定)の分類は、保存時に推定値で固定する（判定後はその値で持つ）。
  before_save :assign_default_kind, if: -> { kind.blank? }
  validates :slug, presence: true, uniqueness: true
  validates :title, presence: true

  def file? = file.attached?
  def link? = url.present?
  def pdf? = file.attached? && file.content_type == "application/pdf"
  def liked_by?(user) = user.present? && likes.exists?(reactor: user)

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

  # メディア種別を symbol で返す（表示の絵文字対応はビュー層に置く）。技術的形態＝サムネ/埋め込みの窓口。
  def media_kind
    return :link if link?
    self.class.kind_for(file.content_type)
  end

  # ユーザ未選択時の「分類」自動推定。確信が持てる範囲だけ（文書は種類を断定できないので nil）。
  def default_kind
    case media_kind
    when :video then "video"
    when :audio then "audio"
    when :image then "image"
    when :link
      case MaterialEmbed.provider_for(url)
      when :spotify then "audio"                # Spotify=音声
      when nil then "web"                       # 埋め込み非対応URL=Webページ
      else "video"                              # YouTube/Vimeo/Dailymotion/ニコニコ=動画
      end
    end # :document（PDF等）は断定不能 → nil（未分類）
  end

  # 実効分類: ユーザ選択があればそれ、なければ自動推定（nil の場合あり=未分類）。
  # 通常は before_save で kind に固定されるが、コールバック前/旧データ用にフォールバックを残す。
  def effective_kind = kind.presence || default_kind

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

  def self.backfill_web_files!
    updated = 0
    with_attached_file.find_each do |material|
      next unless material.pdf? && !material.web_file.attached?
      material.generate_web_file!
      updated += 1 if material.web_file.attached?
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

  def generate_web_file!
    return unless pdf?

    compressed = final = nil
    file.open do |tmp|
      compressed = PdfCompressor.compress(tmp.path)
      return unless compressed
      final = PdfLinearizer.linearize(compressed) || compressed
    end
    File.open(final) { |f| web_file.attach(io: f, filename: file.filename.to_s, content_type: "application/pdf") }
  rescue StandardError => e
    Rails.logger.warn("generate_web_file! failed for Material##{id}: #{e.class}: #{e.message}")
  ensure
    File.unlink(compressed) if compressed && File.exist?(compressed) && compressed != final
    File.unlink(final) if final && File.exist?(final)
  end

  # 書誌情報がひとつでも入っているか（進行ストリップと書誌ゾーンの表示判定）。
  def bibliography_present?
    author.present? || source.present? || published_at.present? ||
      volume.present? || publisher.present? || pages.present? || isbn.present? || page_count.present?
  end

  def rights_label = rights ? RIGHTS_STATUSES[rights] : "未設定"
  def ownership_label = ownership ? OWNERSHIP_STATUSES[ownership] : nil

  # ── 認可述語（自作。モデルに `*_able_by?(user)` を置く方針。規則が増えたら Pundit へ。詳細は
  #    [[project-authorization-approach]]）。Comment#deletable_by? と同じ書き味で揃える。──
  # 現状: メタデータ編集・削除はログイン済みメンバーなら誰でも可（wiki 的）。将来絞るならここを変える。
  def editable_by?(user) = user.present?
  def deletable_by?(user) = user.present?
  # NOTE: confidence（material 単位の信頼度）の UI/述語/validation は撤去済み。カラムは休眠で温存
  #   （DB default "unconfirmed"）。将来は一級カラム毎の confirm 状況管理に置換する（UI は別途設計）。

  # 「未完成資料」の単一の出所: 文字起こしが done でない資料（未着手＝パート0、または途中＝非done パートあり）。
  # transcription_status が done 以外、と同義。将来「主要項目が未確認」等へ広げるならここを広げる。
  scope :transcription_incomplete, -> {
    where("NOT EXISTS (SELECT 1 FROM transcriptions WHERE transcriptions.material_id = materials.id) " \
          "OR EXISTS (SELECT 1 FROM transcriptions WHERE transcriptions.material_id = materials.id AND transcriptions.status != 'done')")
  }

  # 表示用カウント: 完了 / 担当中(担当あり・未完) / 未担当(担当なし・未完) と総数。
  # transcription_status / transcription_progress もこの1フォールから導出する（集計の単一窓口）。
  # 既にロード済みの配列があれば渡して再クエリを避ける（show は parts を持っている）。
  def transcription_counts(parts = transcriptions.to_a)
    done = parts.count { |t| t.status == "done" }
    in_progress = parts.count { |t| t.status != "done" && t.assignee_id.present? }
    { total: parts.size, done: done, in_progress: in_progress, unassigned: parts.size - done - in_progress }
  end

  # パート集約: 0件=todo / 全完了=done / それ以外=drafting。
  def transcription_status(parts = transcriptions.to_a)
    c = transcription_counts(parts)
    return "todo" if c[:total].zero?
    c[:done] == c[:total] ? "done" : "drafting"
  end

  # 表示用 [完了数, 総数]。
  def transcription_progress(parts = transcriptions.to_a)
    c = transcription_counts(parts)
    [ c[:done], c[:total] ]
  end

  private

  # 自動判定できた分類を保存値に固定（断定できない PDF 等は nil のまま＝未分類）。
  def assign_default_kind
    self.kind = default_kind
  end

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
