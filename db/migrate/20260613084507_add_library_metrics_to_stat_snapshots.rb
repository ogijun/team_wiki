class AddLibraryMetricsToStatSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :stat_snapshots, :total_file_bytes, :integer
    add_column :stat_snapshots, :total_pages, :integer
  end
end
