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
    return assignment_notification_phrase(notification) if notification.kind == "assignment"

    PHRASES.fetch(notification.kind)
  end

  def notification_message(notification)
    actor = link_to(display_name(notification.actor), notification.actor)
    return assignment_notification_message(notification, actor) if notification.kind == "assignment"

    safe_join([ actor, "が ", notification_subject_link(notification), "に", notification_icon(notification), notification_phrase(notification) ])
  end

  def notification_icon(notification)
    icon(ICONS.fetch(notification.kind), css: "timeline__icon")
  end

  private

  def assignment_notification_phrase(notification)
    transcription = notification.subject
    if notification.recipient == transcription.assignee
      "あなたに文字起こしを割り当てました"
    else
      "#{transcription.material.title}の文字起こしを引き受けました"
    end
  end

  def assignment_notification_message(notification, actor)
    transcription = notification.subject
    if notification.recipient == transcription.assignee
      safe_join([ actor, "があなたに", notification_subject_link(notification), "を割り当てました" ])
    else
      safe_join([ actor, "が", link_to(transcription.material.title, transcription.material), "の文字起こしを引き受けました" ])
    end
  end
end
