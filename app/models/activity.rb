class Activity < ApplicationRecord
  ACTIONS = %w[
    article.created article.edited article.deleted
    material.added material.deleted
    comment.posted
    transcription.created transcription.edited
    tag.created tag.deleted
    user.joined
  ].freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
end
