class Link < ApplicationRecord
  belongs_to :source_page, class_name: "Page"
  belongs_to :target_page, class_name: "Page", optional: true

  validates :target_title, presence: true
end
