class Article < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :current_revision, class_name: "Revision", optional: true
  has_many :revisions, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings
  has_many :outgoing_links, class_name: "Link", foreign_key: :source_article_id, dependent: :destroy
  has_many :inbound_links, class_name: "Link", foreign_key: :target_article_id, dependent: :nullify
  has_many :materials, dependent: :nullify

  validates :title, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :assign_slug, on: :create

  scope :chronicled, -> { where.not(starts_at: nil).order(:starts_at) }

  validates :starts_precision, inclusion: { in: FuzzyDate::PRECISIONS }, allow_nil: true
  validates :ends_precision, inclusion: { in: FuzzyDate::PRECISIONS }, allow_nil: true
  validate :date_columns_consistent

  # フォーム入力用の仮想アクセサ（ArticlesController が FuzzyDate に変換して保存）
  attr_accessor :start_year, :start_month, :start_day, :start_hour, :start_minute,
                :end_year, :end_month, :end_day, :end_hour, :end_minute

  def starts = FuzzyDate.wrap(starts_at, starts_precision)
  def ends = FuzzyDate.wrap(ends_at, ends_precision)

  def to_param = slug

  # リビジョンの author を初参加順（最初に貢献した順）で重複除去して返す。
  def contributors
    ids = revisions.order(:created_at).pluck(:author_id).uniq
    by_id = User.where(id: ids).with_attached_avatar.index_by(&:id)
    ids.map { |id| by_id[id] }
  end

  private

  def date_columns_consistent
    errors.add(:starts_precision, "が必要です") if starts_at.present? ^ starts_precision.present?
    errors.add(:ends_precision, "が必要です") if ends_at.present? ^ ends_precision.present?
    errors.add(:starts_at, "が必要です") if ends_at.present? && starts_at.blank?
    if starts_at.present? && ends_at.present? && ends_at < starts_at
      errors.add(:ends_at, "は開始以降にしてください")
    end
  end

  def assign_slug
    return if slug.present?
    self.slug = loop do
      candidate = Slug.token
      break candidate unless Article.exists?(slug: candidate)
    end
  end
end
