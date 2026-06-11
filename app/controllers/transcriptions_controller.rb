class TranscriptionsController < ApplicationController
  before_action :set_material, only: %i[show edit update]
  before_action :set_transcription, only: %i[edit update]

  def index
    materials = Material.includes(file_attachment: :blob, transcription: :author).select(&:transcribable?)
    @groups = materials.group_by { |m| m.transcription&.status || "todo" }
  end

  def show
    @transcription = @material.transcription
    redirect_to @material if @transcription.nil?
  end

  def edit
  end

  def update
    was_new = @transcription.new_record?
    @transcription.assign_attributes(transcription_params)
    @transcription.author = Current.user
    if @transcription.save
      ActivityRecorder.record(actor: Current.user,
                              action: was_new ? "transcription.created" : "transcription.edited",
                              subject: @material)
      redirect_to @material, notice: "文字起こしを保存しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_material
    @material = Material.find(params[:material_id])
    redirect_to @material, alert: "この資料は文字起こし対象ではありません。" unless @material.transcribable?
  end

  def set_transcription
    @transcription = @material.transcription || @material.build_transcription
  end

  def transcription_params
    params.require(:transcription).permit(:body, :status, :creation_method, :ai_service, :ai_model)
  end
end
