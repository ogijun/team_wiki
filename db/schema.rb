# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_17_000000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.integer "subject_id"
    t.string "subject_label"
    t.string "subject_type"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["created_at"], name: "index_activities_on_created_at"
    t.index ["subject_type", "subject_id"], name: "index_activities_on_subject"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "articles", force: :cascade do |t|
    t.integer "comments_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "created_by_id", null: false
    t.integer "current_revision_id"
    t.datetime "ends_at"
    t.string "ends_precision"
    t.string "kind"
    t.integer "lock_version", default: 0, null: false
    t.string "slug", null: false
    t.datetime "starts_at"
    t.string "starts_precision"
    t.string "status", default: "stub", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_articles_on_created_by_id"
    t.index ["kind"], name: "index_articles_on_kind"
    t.index ["slug"], name: "index_articles_on_slug", unique: true
    t.index ["starts_at"], name: "index_articles_on_starts_at"
    t.index ["status"], name: "index_articles_on_status"
    t.index ["title"], name: "index_articles_on_title", unique: true
    t.index ["updated_at"], name: "index_articles_on_updated_at"
  end

  create_table "citations", force: :cascade do |t|
    t.integer "article_id", null: false
    t.datetime "created_at", null: false
    t.string "material_handle", null: false
    t.integer "material_id"
    t.datetime "updated_at", null: false
    t.index ["article_id", "material_handle"], name: "index_citations_on_article_id_and_material_handle", unique: true
    t.index ["article_id"], name: "index_citations_on_article_id"
    t.index ["material_id"], name: "index_citations_on_material_id"
  end

  create_table "comments", force: :cascade do |t|
    t.integer "author_id", null: false
    t.text "body", null: false
    t.integer "commentable_id", null: false
    t.string "commentable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_comments_on_author_id"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
  end

  create_table "links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "source_article_id", null: false
    t.integer "target_article_id"
    t.string "target_title", null: false
    t.datetime "updated_at", null: false
    t.index ["source_article_id", "target_title"], name: "index_links_on_source_article_id_and_target_title", unique: true
    t.index ["source_article_id"], name: "index_links_on_source_article_id"
    t.index ["target_article_id"], name: "index_links_on_target_article_id"
    t.index ["target_title"], name: "index_links_on_target_title"
  end

  create_table "materials", force: :cascade do |t|
    t.string "author"
    t.integer "comments_count", default: 0, null: false
    t.string "confidence", default: "unconfirmed", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "file_created_at"
    t.string "isbn"
    t.string "kind"
    t.string "ownership"
    t.integer "page_count"
    t.string "pages"
    t.datetime "published_at"
    t.string "published_precision"
    t.string "publisher"
    t.string "rights"
    t.string "slug", null: false
    t.string "source"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "user_id", null: false
    t.string "volume"
    t.index ["confidence"], name: "index_materials_on_confidence"
    t.index ["ownership"], name: "index_materials_on_ownership"
    t.index ["published_at"], name: "index_materials_on_published_at"
    t.index ["rights"], name: "index_materials_on_rights"
    t.index ["slug"], name: "index_materials_on_slug", unique: true
    t.index ["user_id"], name: "index_materials_on_user_id"
  end

  create_table "revisions", force: :cascade do |t|
    t.integer "article_id", null: false
    t.integer "author_id", null: false
    t.text "body", default: "", null: false
    t.datetime "created_at", null: false
    t.string "edit_summary"
    t.datetime "updated_at", null: false
    t.index ["article_id"], name: "index_revisions_on_article_id"
    t.index ["author_id"], name: "index_revisions_on_author_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "site_settings", force: :cascade do |t|
    t.text "about"
    t.string "brand_name"
    t.datetime "created_at", null: false
    t.text "footer"
    t.string "home_heading"
    t.string "tagline"
    t.datetime "updated_at", null: false
  end

  create_table "stat_snapshots", force: :cascade do |t|
    t.integer "articles_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "materials_count", default: 0, null: false
    t.integer "total_file_bytes"
    t.integer "total_pages"
    t.integer "transcribed_chars", default: 0, null: false
    t.integer "unconfirmed_materials_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_stat_snapshots_on_date", unique: true
  end

  create_table "taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "tag_id", null: false
    t.integer "taggable_id", null: false
    t.string "taggable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id", "taggable_type", "taggable_id"], name: "index_taggings_uniqueness", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  create_table "transcription_revisions", force: :cascade do |t|
    t.integer "author_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "transcription_id", null: false
    t.index ["author_id"], name: "index_transcription_revisions_on_author_id"
    t.index ["transcription_id"], name: "index_transcription_revisions_on_transcription_id"
  end

  create_table "transcriptions", force: :cascade do |t|
    t.string "ai_model"
    t.string "ai_service"
    t.integer "assignee_id"
    t.integer "author_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.string "creation_method"
    t.string "label"
    t.integer "lock_version", default: 0, null: false
    t.integer "material_id", null: false
    t.integer "position", default: 1, null: false
    t.string "status", default: "drafting", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_transcriptions_on_assignee_id"
    t.index ["author_id"], name: "index_transcriptions_on_author_id"
    t.index ["material_id"], name: "index_transcriptions_on_material_id"
  end

  create_table "uploads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_uploads_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.string "bio"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "last_seen_at"
    t.string "name"
    t.string "password_digest"
    t.string "provider"
    t.string "role", default: "editor", null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users"
  add_foreign_key "articles", "users", column: "created_by_id"
  add_foreign_key "citations", "articles"
  add_foreign_key "citations", "materials"
  add_foreign_key "comments", "users", column: "author_id"
  add_foreign_key "links", "articles", column: "source_article_id"
  add_foreign_key "materials", "users"
  add_foreign_key "revisions", "articles"
  add_foreign_key "revisions", "users", column: "author_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "taggings", "tags"
  add_foreign_key "transcription_revisions", "transcriptions"
  add_foreign_key "transcription_revisions", "users", column: "author_id"
  add_foreign_key "transcriptions", "materials"
  add_foreign_key "transcriptions", "users", column: "assignee_id"
  add_foreign_key "transcriptions", "users", column: "author_id"
  add_foreign_key "uploads", "users"
end
