# 文字起こしの履歴・版間 diff（記事の RevisionsController と相似）。
class TranscriptionRevisionsController < ApplicationController
  before_action :set_transcription

  def index
    @revisions = @transcription.revisions.includes(:author).order(created_at: :desc).to_a
    @previous_of = @revisions.each_cons(2).to_h { |newer, older| [ newer.id, older ] }
  end

  def show
    @revision = @transcription.revisions.find(params[:id])
    @base = params[:a].present? ? @transcription.revisions.find(params[:a]) : nil
    if @base
      @diff = Diffy::Diff.new(@base.body, @revision.body).to_s(:html).html_safe
    end
  end

  private

  def set_transcription
    @material = Material.find(params[:material_id])
    @transcription = @material.transcription
    redirect_to @material if @transcription.nil?
  end
end
