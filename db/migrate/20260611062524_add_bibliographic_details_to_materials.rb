class AddBibliographicDetailsToMaterials < ActiveRecord::Migration[8.1]
  def change
    add_column :materials, :isbn, :string
    add_column :materials, :pages, :string
    add_column :materials, :publisher, :string
    add_column :materials, :volume, :string
  end
end
