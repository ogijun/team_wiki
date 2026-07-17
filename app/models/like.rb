class Like < ApplicationRecord
  REACTABLE_TYPES = %w[Article Material Comment Transcription Publication Activity].freeze

  belongs_to :reactor, class_name: "User"
  belongs_to :reactable, polymorphic: true, counter_cache: true

  validates :reactor_id, uniqueness: { scope: %i[reactable_type reactable_id] }
  validates :reactable_type, inclusion: { in: REACTABLE_TYPES }
end
