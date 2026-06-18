class MaterialsController < ApplicationController
  include Pagy::Backend

  before_action :set_material, only: %i[show edit update destroy]

  SORTS = {
    "name"       => "materials.title",
    "type"       => "(materials.url IS NULL)", # 種別＝リンク/ファイルでグルーピング（URL文字列順ではない）
    "uploader"   => "users.name",
    "created_at" => "materials.created_at",
    "published"  => "materials.published_at"
  }.freeze

  def index
    scope = Material.includes(:tags, :transcriptions, user: { avatar_attachment: :blob }).with_attached_file
    scope = scope.joins(:tags).where(tags: { slug: params[:tag] }) if params[:tag].present?

    sort_key = SORTS.key?(params[:sort]) ? params[:sort] : "created_at"
    dir = params[:dir] == "asc" ? "asc" : "desc"
    scope = scope.joins(:user) if sort_key == "uploader"
    scope = scope.order(Arel.sql("#{SORTS[sort_key]} #{dir} NULLS LAST"))

    respond_to do |format|
      format.html do
        per = [ 25, 50, 100 ].include?(params[:per].to_i) ? params[:per].to_i : 25
        @pagy, @materials = pagy(scope, limit: per)
      end
      format.json { render json: scope.map { |m| { slug: m.slug, title: m.title, thumb_url: material_thumb_url(m) } } }
    end
  end

  def show
    @members = User.for_picker.to_a # 担当(assignee)ピッカー用のメンバー一覧
  end

  def new
    @material = Material.new
  end

  def create
    @material = Material.new(material_params.merge(user: Current.user))
    if save_material_with_stub(@material)
      # 重い後処理（ファイル=メタ抽出/PDF linearize、URL=サイトAPI/og:title 補完）は
      # 外部 I/O を含むのでリクエストから外して非同期で行う。
      MaterialPostProcessJob.perform_later(@material)
      Activity.record(actor: Current.user, action: "material.added", subject: @material)
      redirect_to @material, notice: "資料を追加しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @material.update(material_params)
      redirect_to @material, notice: "資料を保存しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    label = @material.title
    @material.destroy
    Activity.record(actor: Current.user, action: "material.deleted", subject_label: label)
    redirect_to materials_url, notice: "資料を削除しました。"
  end

  private

  # 資料保存と、付随作成（初回コメント・チェック時のみのスタブ記事）を1トランザクションで行う。
  # 資料が無効なら save! が RecordInvalid を投げ、ロールバックして new を再描画する。
  def save_material_with_stub(material)
    Material.transaction do
      material.save!
      add_first_comment(material, params[:first_comment])
      StubArticleForMaterial.call(material: material, author: Current.user) if params[:create_stub_article] == "1"
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def set_material
    @material = Material.find(params[:id])
  end

  def material_thumb_url(material)
    return rails_representation_path(material.thumbnail(48)) if material.thumbnailable_file?
    material.preview_image_url
  end

  def material_params
    permitted = [ :title, :description,
                 :source, :author, :rights, :ownership, :tag_names,
                 :isbn, :pages, :page_count, :publisher, :volume,
                 :published_year, :published_month, :published_day ]
    # 根幹（ファイル/URL）は登録時のみ。post 後は不変＝引用の出典を安定させる。
    permitted += [ :file, :url ] unless @material&.persisted?
    # 信頼度の権限は Material の述語に集約（create 時は @material 未設定なので新規インスタンスで判定）。
    permitted << :confidence if (@material || Material.new).confidence_editable_by?(Current.user)
    params.require(:material).permit(*permitted)
  end
end
