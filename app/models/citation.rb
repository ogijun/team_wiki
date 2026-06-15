# 記事本文の [[ref:handle]] を永続化した、記事→資料の引用関係。
# 編集保存時に Article#revise! が本文から張り直す（Link と同じ方式）。
# material は handle(=資料slug)を解決した先。未解決(typo)や資料削除後は nil。
class Citation < ApplicationRecord
  belongs_to :article
  belongs_to :material, optional: true

  validates :material_handle, presence: true
end
