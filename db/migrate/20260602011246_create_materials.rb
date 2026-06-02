class CreateMaterials < ActiveRecord::Migration[8.1]
  def change
    create_table :materials do |t|
      t.string :title
      t.text :description
      t.string :url
      t.references :user, null: false, foreign_key: true
      t.references :page, null: true, foreign_key: true
      t.timestamps
    end
  end
end
