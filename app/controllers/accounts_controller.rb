class AccountsController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    @user.assign_attributes(profile_params)

    if changing_password?
      unless Current.user.authenticate(params.dig(:user, :current_password))
        @user.errors.add(:current_password, "が正しくありません")
        return render :edit, status: :unprocessable_entity
      end
      @user.assign_attributes(password_params)
    end

    if @user.save
      redirect_to edit_account_path, notice: "更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def changing_password?
    params.dig(:user, :password).present?
  end

  def profile_params
    params.require(:user).permit(:name, :email_address, :avatar)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
