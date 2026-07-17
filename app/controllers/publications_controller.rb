class PublicationsController < ApplicationController
  before_action :set_publication, only: %i[show edit update destroy]

  def index
    # 一覧は書影サムネを出すので blob を先読みする（N+1 回避）。
    @publications = Publication.with_attached_cover.order(released_at: :desc, created_at: :desc)
  end

  def show
  end

  def new
    @publication = Publication.new
  end

  def create
    @publication = Publication.new(publication_params)
    @publication.registered_by = Current.user
    if @publication.save
      Activity.record(actor: Current.user, action: "publication.registered", subject: @publication)
      redirect_to @publication, notice: "発売物を登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @publication.update(publication_params)
      Activity.record(actor: Current.user, action: "publication.edited", subject: @publication)
      redirect_to @publication, notice: "発売物を保存しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # 削除後もタイムラインに残すため、商品名をスナップショットしてから消す。
    label = @publication.title
    @publication.destroy
    Activity.record(actor: Current.user, action: "publication.deleted", subject_label: label)
    redirect_to publications_url, notice: "発売物を削除しました。"
  end

  private

  def set_publication
    @publication = Publication.find(params[:id])
  end

  def publication_params
    params.require(:publication).permit(:title, :kind, :sales_status, :store_url, :cover,
                                        :released_year, :released_month, :released_day,
                                        :released_hour, :released_minute)
  end
end
