class AddAboutToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :site_settings, :about, :text
  end
end
