class AboutController < ApplicationController
  def show
    @setting = SiteSetting.instance
  end
end
