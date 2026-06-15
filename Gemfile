source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Live, auto-updating relative timestamps ("2分前") [https://github.com/basecamp/local_time]
gem "local_time"
# Fetch wrapper with CSRF/Accept handled for Rails [https://github.com/rails/requestjs-rails]
gem "requestjs-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Discord OAuth login
gem "omniauth-discord"
gem "omniauth-rails_csrf_protection"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Cloudflare R2 (S3-compatible) for Active Storage in production
gem "aws-sdk-s3", "~> 1.224", require: false

# Pagination
gem "pagy", "~> 9.3"

# Reusable, unit-testable view components
gem "view_component", "~> 4.0"

# Wiki content: GitHub-flavored Markdown rendering and revision diffs
gem "commonmarker", "~> 2.0"
gem "diffy", "~> 3.4"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Load ENV from .env in dev/test (needed for puma-dev which doesn't inherit shell env)
  gem "dotenv-rails"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Minitest 専用 cop（assert_equal の引数順・assert_empty/assert_nil 等の idiom 化）
  gem "rubocop-minitest", require: false

  # スレッド安全 cop（単一 Puma の複数スレッド運用向け・可変クラス状態の検出）
  gem "rubocop-thread_safety", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

gem "litestream", "~> 0.14.0"

gem "pdf-reader", "~> 2.15"

gem "factory_bot_rails", "~> 6.5", groups: [ :development, :test ]

gem "rubocop-migration", "~> 0.7.1", group: :development, require: false
