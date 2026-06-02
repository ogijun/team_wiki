class AddSlugToMaterials < ActiveRecord::Migration[8.1]
  def up
    add_column :materials, :slug, :string
    Material.reset_column_information
    Material.find_each { |m| m.update_column(:slug, unique_token) }
    change_column_null :materials, :slug, false
    add_index :materials, :slug, unique: true
  end

  def down
    remove_index :materials, :slug
    remove_column :materials, :slug
  end

  private

  def unique_token
    loop do
      candidate = Slug.token
      break candidate unless Material.exists?(slug: candidate)
    end
  end
end
