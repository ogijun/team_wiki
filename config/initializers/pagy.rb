require "pagy/extras/overflow"

Pagy::DEFAULT[:limit] = 25          # 1ページの既定件数
Pagy::DEFAULT[:overflow] = :last_page
