class TranscriptionsController < ApplicationController
  before_action :set_material, only: %i[new create show edit update destroy assign]
  before_action :set_transcription, only: %i[show edit update destroy assign]
  before_action :set_members, only: %i[new create edit update] # create/update は失敗時にフォーム再描画

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

  # 担当(assignee)の設定/変更/解除。誰でも自由。編集とは独立した弱いサインなので、版(lock_version)も
  # author も触らない。assignee_id だけを update_column で直接書く（本文編集との楽観ロック衝突を避け、
  # updated_at も上げない＝「最近更新」を担当変更で動かさない）。
  def assign
    return head :forbidden unless @transcription.assignable_by?(Current.user)
    assignee = params[:assignee_id].present? ? User.find(params[:assignee_id]) : nil
    @transcription.update_column(:assignee_id, assignee&.id)
    Notification.emit(recipient: assignee, actor: Current.user, kind: "assignment", subject: @transcription) if assignee
    # 活動は「担当にされた人」を主語(actor)にする（タイムラインは「xxx が zzz の担当になりました」と出る）。
    # 解除(assignee=nil)は記録しない（弱いサインの取り下げまでは追わない）。
    Activity.record(actor: assignee, action: "transcription.assigned", subject: @material) if assignee
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          @transcription,
          partial: "materials/transcription_part",
          locals: { material: @material, t: @transcription, members: User.for_picker.to_a,
                    numbered: @material.transcriptions.count > 1 }
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
  end

  def set_transcription
    @transcription = @material.transcriptions.find(params[:id])
  end

  # 担当ピッカー用のメンバー一覧（アバター eager load・名前順）。フォーム内で直接クエリしない。
  def set_members
    @members = User.for_picker.to_a
  end

  def transcription_params
    params.require(:transcription).permit(:body, :status, :creation_method, :ai_service, :ai_model, :label, :assignee_id, :lock_version)
  end
end
