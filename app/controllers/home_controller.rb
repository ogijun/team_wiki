class HomeController < ApplicationController
  def index
    @recent_articles = Article.order(updated_at: :desc).limit(5)
    # 生取得→squash まで。連続同一ユーザの畳み込みと 10件 cap はビュー側で「畳んでから cap」する
    # （cap 後に畳むと行数が減るため。畳んだぶん他ユーザの活動が繰り上がって 10 行を保つ）。
    @recent_activity_groups = ActivityGrouper.call(
      Activity.includes(:user, :subject).order(created_at: :desc).limit(60)
    )
    @stub_articles = Article.where(status: %w[stub writing]).order(updated_at: :desc).limit(5)
    @stats = StatSnapshot.current_values
    @daily = ActivityStats.daily_by_type
    @hourly = ActivityStats.hourly_by_type
  end
end
