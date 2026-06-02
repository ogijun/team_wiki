class Material < ApplicationRecord
  belongs_to :user
  belongs_to :page, optional: true
  has_one_attached :file
end
