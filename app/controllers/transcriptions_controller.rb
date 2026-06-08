class TranscriptionsController < ApplicationController
  before_action :set_material, only: %i[edit update]

  def index
    materials = Material.includes(file_attachment: :blob, transcription: :author).select(&:transcribable?)
    @groups = materials.group_by { |m| m.transcription&.status || "todo" }
  end

  def edit
    @transcription = @material.transcription || @material.build_transcription
  end

  def update
    @transcription = @material.transcription || @material.build_transcription
    @transcription.assign_attributes(transcription_params)
    @transcription.author = Current.user
    if @transcription.save
      redirect_to @material, notice: "トランスクリプトを保存しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_material
    @material = Material.find(params[:material_id])
    redirect_to @material, alert: "この資料はトランスクリプト対象ではありません。" unless @material.transcribable?
  end

  def transcription_params
    params.require(:transcription).permit(:body, :status)
  end
end
