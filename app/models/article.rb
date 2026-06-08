class Article < ApplicationRecord
  include FuzzyDateAttributable
  include Taggable

  KINDS = { "work" => "作品", "person" => "人物", "event" => "出来事" }.freeze
  STATUSES = { "stub" => "スタブ", "writing" => "執筆中", "done" => "完成" }.freeze

  belongs_to :created_by, class_name: "User"
  belongs_to :current_revision, class_name: "Revision", optional: true
  has_many :revisions, dependent: :destroy
  has_many :outgoing_links, class_name: "Link", foreign_key: :source_article_id, dependent: :destroy
  has_many :inbound_links, class_name: "Link", foreign_key: :target_article_id, dependent: :nullify
  has_many :materials, dependent: :nullify

  validates :title, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  # フォームの「未分類」(include_blank) は "" を送る。空文字は nil 扱いにして allow_nil を効かせる。
  normalizes :kind, with: ->(v) { v.presence }
  validates :kind, inclusion: { in: KINDS.keys }, allow_nil: true
  validates :status, inclusion: { in: STATUSES.keys }

  fuzzy_date_attribute :starts_at, accessor: :start
  fuzzy_date_attribute :ends_at, accessor: :end

  before_validation :assign_slug, on: :create

  scope :chronicled, -> { where.not(starts_at: nil).order(:starts_at) }

  validates :starts_precision, inclusion: { in: FuzzyDate::PRECISIONS }, allow_nil: true
  validates :ends_precision, inclusion: { in: FuzzyDate::PRECISIONS }, allow_nil: true

  validate :date_range_consistent

  def to_param = slug

  def kind_label = kind ? KINDS[kind] : "未分類"
  def status_label = STATUSES[status]

  # リビジョンの author を初参加順（最初に貢献した順）で重複除去して返す。
  def contributors
    ids = revisions.order(:created_at).pluck(:author_id).uniq
    by_id = User.where(id: ids).with_attached_avatar.index_by(&:id)
    ids.map { |id| by_id[id] }
  end

  private

  def date_range_consistent
    errors.add(:starts_at, "が必要です") if ends_at.present? && starts_at.blank?
    if starts_at.present? && ends_at.present? && ends_at < starts_at
      errors.add(:ends_at, "は開始以降にしてください")
    end
  end

  def assign_slug
    self.slug ||= Slug.unique_token { |c| Article.exists?(slug: c) }
  end
end
