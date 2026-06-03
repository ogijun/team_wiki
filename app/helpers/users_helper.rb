module UsersHelper
  AVATAR_COLORS = %w[#2563eb #059669 #d97706 #dc2626 #7c3aed #0891b2].freeze

  def display_name(user)
    user.name.presence || user.email_address
  end

  def avatar_color(user)
    AVATAR_COLORS[user.id.to_i % AVATAR_COLORS.size]
  end

  def avatar_tag(user, size: 40)
    if user.avatar.attached?
      image_tag url_for(user.avatar), width: size, height: size, class: "avatar"
    else
      initial = display_name(user).to_s.strip.first.to_s.upcase
      content_tag(:span, initial,
                  class: "avatar avatar-initial",
                  style: "width:#{size}px;height:#{size}px;line-height:#{size}px;background:#{avatar_color(user)};")
    end
  end
end
