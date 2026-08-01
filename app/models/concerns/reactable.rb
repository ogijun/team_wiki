module Reactable
  extend ActiveSupport::Concern

  # Like と Notification の対象になれるモデルの共通部分。
  # 対象集合は Like::REACTABLE_TYPES と一致する（テストで担保）。
  included do
    has_many :likes, as: :reactable, dependent: :destroy
    has_many :notifications, as: :subject, dependent: :destroy
  end

  def liked_by?(user) = user.present? && likes.exists?(reactor: user)
end
