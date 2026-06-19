class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy
  has_many :articles, through: :taggings, source: :taggable, source_type: "Article"
  has_many :materials, through: :taggings, source: :taggable, source_type: "Material"
  has_many :activities, as: :subject, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  scope :with_usage_count, -> {
    left_joins(:taggings)
      .group(:id)
      .order(Arel.sql("COUNT(taggings.id) DESC"))
      .order(:name)
      .select("tags.*, COUNT(taggings.id) AS usage_count")
  }

  before_validation :assign_slug, on: :create

  def to_param = slug

  private

  def assign_slug
    return if slug.present?
    base = Slug.slugify(name)
    candidate = base
    n = 1
    while Tag.exists?(slug: candidate)
      n += 1
      candidate = "#{base}-#{n}"
    end
    self.slug = candidate
  end
end
