class HomeController < ApplicationController
  def index
    # 連続同一ユーザの畳み込みと 10 件 cap はビュー側で「畳んでから cap」する。
    @recent_activity_groups = ActivityGrouper.call(
      Activity.includes(:user, :subject).order(created_at: :desc).limit(60)
    )
    @stats = StatSnapshot.current_values
    # 「未完成資料」は単一の出所(scope)から。count は全件数、list は上限8件
    # （残りは右カラムの「すべての未完成資料を表示」リンクで進捗ボードへ誘導）。
    incomplete = Material.transcription_incomplete
    @incomplete_count = incomplete.count
    @incomplete_materials = incomplete.includes(:transcriptions).order(updated_at: :desc).limit(8)
    @daily = ActivityStats.daily_by_type
    @hourly = ActivityStats.hourly_by_type
  end
end
