# 日次スナップショットの推移グラフ（直近90日）。
class StatsController < ApplicationController
  def index
    @daily = ActivityStats.daily_by_type
    @hourly = ActivityStats.hourly_by_type
    @snapshots = StatSnapshot.order(:date).last(90)
  end
end
