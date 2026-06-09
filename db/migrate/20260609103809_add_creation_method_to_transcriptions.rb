class AddCreationMethodToTranscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :transcriptions, :creation_method, :string
    add_column :transcriptions, :ai_service, :string
    add_column :transcriptions, :ai_model, :string
  end
end
