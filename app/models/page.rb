class Page < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :current_revision, class_name: "Revision", optional: true
  has_many :revisions, dependent: :destroy

  validates :title, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :assign_slug, on: :create

  def to_param = slug

  private

  def assign_slug
    return if slug.present?
    base = Slug.slugify(title)
    candidate = base
    n = 1
    while Page.exists?(slug: candidate)
      n += 1
      candidate = "#{base}-#{n}"
    end
    self.slug = candidate
  end
end
