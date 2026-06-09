# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "local-time", to: "local-time.es2017-esm.js" # basecamp/local_time（gem 同梱の ESM を Propshaft 配信）
pin_all_from "app/javascript/controllers", under: "controllers"
