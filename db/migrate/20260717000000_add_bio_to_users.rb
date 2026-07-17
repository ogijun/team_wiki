class AddBioToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :bio, :string
  end
end
