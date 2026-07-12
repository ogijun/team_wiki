class Publication < ApplicationRecord
  include FuzzyDateAttributable

  KINDS = { "book" => "著書", "video" => "映像", "audio" => "音楽", "other" => "その他" }.freeze
  SALES_STATUSES = { "on_sale" => "販売中", "out_of_print" => "絶版", "unreleased" => "未発売" }.freeze

  belongs_to :registered_by, class_name: "User"
  # 削除後もタイムラインは subject_label のスナップショットで表示する（参照だけ外す）。
  has_many :activities, as: :subject, dependent: :nullify

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

  # 発売日を持つものを時系列で（年表統合のソース）。
  scope :chronicled, -> { where.not(released_at: nil).order(:released_at) }

  def kind_label = KINDS[kind]
  def sales_status_label = SALES_STATUSES[sales_status]
  def purchasable? = sales_status == "on_sale" && store_url.present?

  # 認可述語（自作。モデルに `*_able_by?(user)` を置く方針）。現状はログイン済みメンバーなら可。
  def editable_by?(user) = user.present?
  def deletable_by?(user) = user.present?
end
