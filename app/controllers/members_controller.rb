class MembersController < ApplicationController
  # 公開版メンバー一覧。管理列（最終ログイン等）は UsersController#index に残す。
  def index
    @members = User.with_attached_avatar.order(:created_at)
  end
end
