module NotificationsHelper
  PHRASES = {
    "like" => "いいねしました",
    "comment" => "コメントしました",
    "assignment" => "文字起こしを割り当てました"
  }.freeze

  ICONS = {
    "like" => "heart",
    "comment" => "message-circle",
    "assignment" => "audio-lines"
  }.freeze

  def notification_phrase(notification)
    PHRASES.fetch(notification.kind)
  end

  def notification_icon(notification)
    icon(ICONS.fetch(notification.kind), css: "timeline__icon")
  end
end
