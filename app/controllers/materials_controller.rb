class MaterialsController < ApplicationController
  include Pagy::Backend

  before_action :set_material, only: %i[show edit update destroy]

  SORTS = {
    "name"       => "materials.title",
    "type"       => "materials.url",
    "uploader"   => "users.name",
    "created_at" => "materials.created_at"
  }.freeze

  def index
    scope = Material.includes(:user, :article, :tags)
    scope = scope.joins(:tags).where(tags: { slug: params[:tag] }) if params[:tag].present?

    sort_key = SORTS.key?(params[:sort]) ? params[:sort] : "created_at"
    dir = params[:dir] == "asc" ? "asc" : "desc"
    scope = scope.joins(:user) if sort_key == "uploader"
    scope = scope.order(Arel.sql("#{SORTS[sort_key]} #{dir} NULLS LAST"))

    respond_to do |format|
      format.html do
        per = [25, 50, 100].include?(params[:per].to_i) ? params[:per].to_i : 25
        @pagy, @materials = pagy(scope, limit: per)
      end
      format.json { render json: scope.map { |m| { slug: m.slug, title: m.display_title } } }
    end
  end

  def show
  end

  def new
    @material = Material.new(article_id: params[:article_id])
  end

  def create
    @material = Material.new(material_params.merge(user: Current.user))
    assign_published(@material)
    if @material.save
      sync_tags(@material, params.dig(:material, :tag_names))
      ActivityRecorder.record(actor: Current.user, action: "material.added", subject: @material)
      redirect_to @material
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @material.assign_attributes(material_params)
    assign_published(@material)
    if @material.save
      sync_tags(@material, params.dig(:material, :tag_names))
      redirect_to @material
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    label = @material.display_title
    @material.destroy
    ActivityRecorder.record(actor: Current.user, action: "material.deleted", subject_label: label)
    redirect_to materials_url
  end

  private

  def set_material
    @material = Material.find(params[:id])
  end

  def material_params
    params.require(:material).permit(:title, :description, :url, :file, :article_id,
                                     :source, :author, :retrieved_on,
                                     :published_year, :published_month, :published_day)
  end

  def assign_published(material)
    fd = FuzzyDate.from_parts(
      year: material_params[:published_year], month: material_params[:published_month],
      day: material_params[:published_day], hour: nil, minute: nil
    )
    material.published_at = fd&.at
    material.published_precision = fd&.precision
  end

  def sync_tags(material, str)
    names = str.to_s.split(/[,、]/).map(&:strip).reject(&:empty?).uniq
    material.tags = names.map { |name| Tag.find_or_create_by!(name: name) }
  end
end
