# 日次スナップショットの推移グラフ（直近90日）。
class StatsController < ApplicationController
  def index
    @snapshots = StatSnapshot.order(:date).last(90)
  end
end
