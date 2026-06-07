class SettingsController < ApplicationController
  before_action :require_admin

  def edit
    @setting = SiteSetting.instance
  end

  def update
    @setting = SiteSetting.instance
    @setting.logo.purge if params[:remove_logo] == "1"
    if @setting.update(setting_params)
      redirect_to edit_settings_path, notice: "設定を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def setting_params
    params.require(:site_setting).permit(:brand_name, :logo, :about, :footer)
  end
end
