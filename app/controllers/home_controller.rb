class HomeController < ApplicationController
  def index
    # 連続同一ユーザの畳み込みと 10 件 cap はビュー側で「畳んでから cap」する。
    @recent_activity_groups = ActivityGrouper.call(
      Activity.includes(:user, :subject).order(created_at: :desc).limit(60)
    )
    @stats = StatSnapshot.current_values
    # 「未完成資料」は単一の出所(scope)から。サマリ count と右カラム list が一致する。
    incomplete = Material.transcription_incomplete
    @incomplete_count = incomplete.count
    @incomplete_materials = incomplete.includes(:transcriptions).order(updated_at: :desc).limit(8)
    @daily = ActivityStats.daily_by_type
    @hourly = ActivityStats.hourly_by_type
  end
end
