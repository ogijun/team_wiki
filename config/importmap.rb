# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "local-time", to: "local-time.es2017-esm.js" # basecamp/local_time（gem 同梱の ESM を Propshaft 配信）
pin "pdfjs-dist", to: "https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/build/pdf.min.mjs" # PDF部分読み込みビューア（worker は pdf_controller 内で同CDNを指定）
pin_all_from "app/javascript/controllers", under: "controllers"
