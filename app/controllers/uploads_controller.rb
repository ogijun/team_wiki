class UploadsController < ApplicationController
  def create
    upload = Upload.new(user: Current.user)
    upload.file.attach(params[:file])
    if upload.save
      render json: { url: url_for(upload.file) }
    else
      render json: { errors: upload.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
