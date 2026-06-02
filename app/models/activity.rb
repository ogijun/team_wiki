class Activity < ApplicationRecord
  ACTIONS = %w[
    page.created page.edited page.deleted
    material.added material.deleted
    tag.created tag.deleted
    user.joined
  ].freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
end
