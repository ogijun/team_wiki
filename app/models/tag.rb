class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy
  has_many :pages, through: :taggings, source: :taggable, source_type: "Page"

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  scope :with_usage_count, -> {
    left_joins(:taggings)
      .group(:id)
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
