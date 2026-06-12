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
    scope = Material.includes(:tags, :transcription, user: { avatar_attachment: :blob }).with_attached_file
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
  end

  def new
    @material = Material.new
  end

  def create
    @material = Material.new(material_params.merge(user: Current.user))
    autofill_from_url(@material)
    if save_material_with_stub(@material)
      ActivityRecorder.record(actor: Current.user, action: "material.added", subject: @material)
      redirect_to @material
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @material.update(material_params)
      redirect_to @material
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    label = @material.title
    @material.destroy
    ActivityRecorder.record(actor: Current.user, action: "material.deleted", subject_label: label)
    redirect_to materials_url
  end

  private

  # 資料保存と、付随作成（初回コメント・チェック時のみのスタブ記事）を1トランザクションで行う。
  # 資料が無効なら save! が RecordInvalid を投げ、ロールバックして new を再描画する。
  def save_material_with_stub(material)
    Material.transaction do
      material.save!
      add_first_comment(material, params[:first_comment])
      record_extracted_metadata(material)
      StubArticleForMaterial.call(material: material, author: Current.user) if params[:create_stub_article] == "1"
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # EXIF/PDF メタデータの抽出結果を記録する。日時はファイル作成日カラムへ
  # （発行日とは別物：スキャン/撮影日であることが多いため年表には使わない）、
  # その他はコメントに候補として列挙し、人が書誌へ転記する。
  def record_extracted_metadata(material)
    result = MaterialMetadataExtractor.call(material)
    material.update_column(:file_created_at, result[:file_created_at]) if result[:file_created_at]
    return if result[:details].empty?

    lines = result[:details].map { |label, value| "・#{label}: #{value}" }
    material.comments.create!(
      author: Current.user,
      body: "📄 ファイルのメタデータから自動抽出した候補です（要確認）:\n#{lines.join("\n")}\n書誌情報の参考にどうぞ。"
    )
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
                 :source, :author, :rights, :tag_names,
                 :isbn, :pages, :publisher, :volume,
                 :published_year, :published_month, :published_day ]
    # 根幹（ファイル/URL）は登録時のみ。post 後は不変＝引用の出典を安定させる。
    permitted += [ :file, :url ] unless @material&.persisted?
    permitted << :confidence if Current.user&.admin?
    params.require(:material).permit(*permitted)
  end

  # URL 資料の空欄をサイト側メタデータで補完する。
  # title: 動画サイト(YouTube/Dailymotion/Vimeo)の API → だめなら og:title。
  #        取得できなければ何もしない＝モデルの ensure_title が url で必ず埋める。
  # 発行日: 動画の公開日が取れて未記入なら day 精度で設定（動画はサイト公開日≒発行日とみなす）。
  def autofill_from_url(material)
    return if material.file.attached? || material.url.blank?

    video = VideoMetadata.call(material.url)
    if material.title.blank?
      material.title = video&.dig(:title) || OgTitleFetcher.call(material.url)
    end
    if material.published_at.nil? && (date = video&.dig(:published_on))
      material.published_at = date.in_time_zone
      material.published_precision = "day"
    end
  end
end
