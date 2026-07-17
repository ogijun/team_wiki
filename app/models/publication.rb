class Publication < ApplicationRecord
  include FuzzyDateAttributable

  KINDS = { "book" => "著書", "video" => "映像", "audio" => "音楽", "other" => "その他" }.freeze
  SALES_STATUSES = { "on_sale" => "販売中", "out_of_print" => "絶版", "unreleased" => "未発売" }.freeze

  belongs_to :registered_by, class_name: "User"
  # 書影（ジャケット写真）。発売物にとって書影は「対象そのもの」なので詳細ページの主役に据える。
  # いまは1枚だけ（複数化するなら has_many_attached :cover へ差し替える。名前が同じなので既存 blob は残る）。
  has_one_attached :cover
  # 削除後もタイムラインは subject_label のスナップショットで表示する（参照だけ外す）。
  has_many :activities, as: :subject, dependent: :nullify
  has_many :likes, as: :reactable, dependent: :destroy

  # 書影は画像のみ（資料と違い PDF/動画/音声は受け付けない）。Material::THUMBNAIL_TYPES と同じ4形式。
  COVER_CONTENT_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  # 書影1枚の上限。書影は「1枚の写真」なので資料の 1GB は過剰。スマホの高解像度写真（数MB）や
  # スキャンした表紙が余裕で収まり、事故的な巨大アップロードは弾ける 10MB に置く。
  COVER_MAX_BYTES = 10.megabytes

  # 列=released_at → アクセサ released_* / メソッド released を自動生成（accessor: は不要）。
  fuzzy_date_attribute :released_at

  validates :title, presence: true
  validates :kind, inclusion: { in: KINDS.keys }
  validates :sales_status, inclusion: { in: SALES_STATUSES.keys }
  validates :released_precision, inclusion: { in: FuzzyDate::PRECISIONS }, allow_nil: true
  # フォームの空欄は "" で来る。nil にして allow_nil を効かせる。
  normalizes :store_url, with: ->(v) { v.presence }
  validates :store_url, format: { with: %r{\Ahttps?://\S+\z}, message: "は http(s) で始まる URL を指定してください" },
                        allow_nil: true
  validate :acceptable_cover, if: -> { cover.attached? }

  # 発売日を持つものを時系列で（年表統合のソース）。
  scope :chronicled, -> { where.not(released_at: nil).order(:released_at) }

  def kind_label = KINDS[kind]
  def sales_status_label = SALES_STATUSES[sales_status]
  def purchasable? = sales_status == "on_sale" && store_url.present?

  # 書影のサムネ（variant）。未設定なら nil＝ビュー側は package アイコンにフォールバックする。
  def cover_thumbnail(px)
    cover.representation(resize_to_limit: [ px, px ]) if cover.attached?
  end

  # 認可述語（自作。モデルに `*_able_by?(user)` を置く方針）。現状はログイン済みメンバーなら可。
  def editable_by?(user) = user.present?
  def deletable_by?(user) = user.present?
  def liked_by?(user) = user.present? && likes.exists?(reactor: user)

  private

  def acceptable_cover
    errors.add(:cover, "は画像ファイル（PNG/JPEG/GIF/WebP）にしてください") unless COVER_CONTENT_TYPES.include?(cover.content_type)
    errors.add(:cover, "が大きすぎます") if cover.byte_size.to_i > COVER_MAX_BYTES
  end
end
