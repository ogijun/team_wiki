# 記事・資料に紐づく複数コメント（polymorphic）。プレーンテキスト本文。
# 旧「メモ」を置き換え、新規作成時の初回コメントもこれで表す。
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true, counter_cache: true
  belongs_to :author, class_name: "User"
  has_many :likes, as: :reactable, dependent: :destroy
  has_many :notifications, as: :subject, dependent: :destroy

  validates :body, presence: true

  def liked_by?(user) = user.present? && likes.exists?(reactor: user)

  # 削除できるのは投稿者本人か admin のみ（編集は不可）。
  def deletable_by?(user)
    user.present? && (user.admin? || user == author)
  end
end
