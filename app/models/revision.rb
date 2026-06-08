class Revision < ApplicationRecord
  belongs_to :article
  belongs_to :author, class_name: "User"

  validates :body, presence: true
end
