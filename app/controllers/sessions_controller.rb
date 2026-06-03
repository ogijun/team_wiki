class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create failure]

  def new
  end

  def create
    auth = request.env["omniauth.auth"]
    membership = DiscordGuildMembership.call(
      token: auth.dig("credentials", "token"),
      guild_id: Rails.configuration.x.discord.guild_id
    )

    unless membership.member? && membership.role_ids.include?(Rails.configuration.x.discord.required_role_id.to_s)
      return redirect_to new_session_path, alert: "このサービスへのアクセス権がありません。"
    end

    user = upsert_user(auth)
    start_new_session_for user
    redirect_to after_authentication_url
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  def failure
    redirect_to new_session_path, alert: "ログインに失敗しました。"
  end

  private

  def upsert_user(auth)
    user = User.find_or_initialize_by(provider: "discord", uid: auth.uid.to_s)
    if user.new_record?
      user.email_address = auth.dig("info", "email")
      user.name = auth.dig("info", "name")
      user.avatar_url = auth.dig("info", "image")
      user.save!
    end
    user
  end
end
