# 日次の統計スナップショット（config/recurring.yml が JST 23:55 にスケジュール）。
class StatSnapshotJob < ApplicationJob
  queue_as :default

  def perform
    StatSnapshot.capture!
  end
end
