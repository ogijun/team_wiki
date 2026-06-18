class TranscriptionsController < ApplicationController
  before_action :set_material, only: %i[new create show edit update destroy assign]
  before_action :set_transcription, only: %i[show edit update destroy assign]

  def new
    @transcription = @material.transcriptions.build
  end

  def create
    @transcription = @material.transcriptions.build(transcription_params)
    @transcription.author = Current.user
    @transcription.position = @material.transcriptions.maximum(:position).to_i + 1
    if @transcription.save
      @transcription.revisions.create!(author: Current.user, body: @transcription.body) if @transcription.body.present?
      Activity.record(actor: Current.user, action: "transcription.created", subject: @material)
      redirect_to @material, notice: "文字起こしパートを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    @transcription.assign_attributes(transcription_params)
    @transcription.author = Current.user
    if @transcription.save
      @transcription.revisions.create!(author: Current.user, body: @transcription.body) if @transcription.saved_change_to_body?
      Activity.record(actor: Current.user, action: "transcription.edited", subject: @material)
      redirect_to @material, notice: "文字起こしを保存しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::StaleObjectError
    @transcription.reload
    flash.now[:alert] = "他の人が先に更新しました。最新の内容を確認してから保存し直してください。"
    render :edit, status: :unprocessable_entity
  end

  # 担当(assignee)の設定/変更/解除。誰でも自由。編集とは独立（版も author も触らない）。
  def assign
    return head :forbidden unless @transcription.assignable_by?(Current.user)
    assignee = params[:assignee_id].present? ? User.find(params[:assignee_id]) : nil
    @transcription.update!(assignee: assignee)
    # 活動は「担当にされた人」を主語(actor)にする（タイムラインは「xxx が zzz の担当になりました」と出る）。
    Activity.record(actor: assignee, action: "transcription.assigned", subject: @material) if assignee
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          @transcription,
          partial: "materials/transcription_part",
          locals: { material: @material, t: @transcription, members: User.with_attached_avatar.order(:name).to_a }
        )
      end
      format.html { redirect_to @material }
    end
  end

  def destroy
    @transcription.destroy
    redirect_to @material, notice: "文字起こしパートを削除しました。"
  end

  private

  def set_material
    @material = Material.find(params[:material_id])
    redirect_to @material, alert: "この資料は文字起こし対象ではありません。" unless @material.transcribable?
  end

  def set_transcription
    @transcription = @material.transcriptions.find(params[:id])
  end

  def transcription_params
    params.require(:transcription).permit(:body, :status, :creation_method, :ai_service, :ai_model, :label, :assignee_id, :lock_version)
  end
end
