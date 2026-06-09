class RemoveArticleReferenceFromMaterials < ActiveRecord::Migration[8.1]
  def change
    # Material↔Article は本文の [[ref:]] 由来の citations(多対多)で表現するため、
    # belongs_to の article_id は廃止する。
    remove_reference :materials, :article, foreign_key: true
  end
end
