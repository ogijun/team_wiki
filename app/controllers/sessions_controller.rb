class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create failure]
  rate_limit to: 20, within: 1.minute, only: :create, with: -> { redirect_to new_session_path, alert: "しばらく待ってから再試行してください。" }

  def new
  end

  def create
    auth = request.env["omniauth.auth"]
    return redirect_to new_session_path, alert: "認証エラーが発生しました。" if auth.nil?

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
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to new_session_path, alert: "ログインできませんでした。管理者にお問い合わせください。"
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
      user.avatar_url = safe_avatar_url(auth.dig("info", "image"))
      user.save!
    end
    user
  end

  def safe_avatar_url(url)
    return nil if url.blank?
    host = URI.parse(url).host
    %w[cdn.discordapp.com media.discordapp.net].include?(host) ? url : nil
  rescue URI::InvalidURIError
    nil
  end
end
