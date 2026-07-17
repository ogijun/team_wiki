class AddLikesCountToReactables < ActiveRecord::Migration[8.1]
  def change
    %i[articles materials comments transcriptions activities].each do |table|
      add_column table, :likes_count, :integer, default: 0, null: false
    end
  end
end
