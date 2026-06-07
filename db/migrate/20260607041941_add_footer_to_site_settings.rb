class AddFooterToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :site_settings, :footer, :text
  end
end
