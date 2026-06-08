class MakeMaterialTitleRequired < ActiveRecord::Migration[8.1]
  def change
    change_column_null :materials, :title, false
  end
end
