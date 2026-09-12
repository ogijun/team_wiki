module CommentsHelper
  def render_comment_body(body, members)
    users = members.index_by { |user| user.id.to_s }
    parts = []
    cursor = 0

    body.to_s.to_enum(:scan, Comment::MENTION_PATTERN).each do
      match = Regexp.last_match
      parts << body.to_s[cursor...match.begin(0)]
      user = users[match[1]]
      parts << (user ? link_to("@#{display_name(user)}", user, class: "mention") : match[0])
      cursor = match.end(0)
    end
    parts << body.to_s[cursor..]
    safe_join(parts)
  end
end
