class MaterialsController < ApplicationController
  before_action :set_material, only: %i[show edit update destroy]

  def index
    @materials = Material.includes(:user, :page, :tags).order(created_at: :desc)
    if params[:tag].present?
      @materials = @materials.joins(:tags).where(tags: { slug: params[:tag] })
    end
  end

  def show
  end

  def new
    @material = Material.new(page_id: params[:page_id])
  end

  def create
    @material = Material.new(material_params.merge(user: Current.user))
    if @material.save
      sync_tags(@material, params.dig(:material, :tag_names))
      redirect_to @material
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @material.update(material_params)
      sync_tags(@material, params.dig(:material, :tag_names))
      redirect_to @material
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @material.destroy
    redirect_to materials_url
  end

  private

  def set_material
    @material = Material.find(params[:id])
  end

  def material_params
    params.require(:material).permit(:title, :description, :url, :file, :page_id)
  end

  def sync_tags(material, str)
    names = str.to_s.split(/[,、]/).map(&:strip).reject(&:empty?).uniq
    material.tags = names.map { |name| Tag.find_or_create_by!(name: name) }
  end
end
