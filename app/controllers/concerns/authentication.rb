module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    before_action :track_last_seen
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def require_admin
      return if Current.user&.admin?
      redirect_to root_path, alert: "この操作には管理者権限が必要です。", status: :see_other
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    # 最終アクセス(last_seen_at)を記録。毎リクエスト書き込みを避けるため約10分スロットル。
    # update_column で validations/callbacks/updated_at を回避（弱いサインなので軽量に）。
    def track_last_seen
      user = Current.user
      return if user.nil? || (user.last_seen_at && user.last_seen_at > 10.minutes.ago)
      user.update_column(:last_seen_at, Time.current)
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax, secure: Rails.env.production? }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
