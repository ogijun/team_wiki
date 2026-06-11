# 文字起こし本文の1版（追記のみ）。記事の Revision と相似。
class TranscriptionRevision < ApplicationRecord
  belongs_to :transcription
  belongs_to :author, class_name: "User"

  validates :body, presence: true
end
