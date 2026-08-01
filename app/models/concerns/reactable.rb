module Reactable
  extend ActiveSupport::Concern

  included do
    has_many :likes, as: :reactable, dependent: :destroy
    has_many :notifications, as: :subject, dependent: :destroy
  end

  def liked_by?(user) = user.present? && likes.exists?(reactor: user)
end
