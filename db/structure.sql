CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "sessions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "ip_address" varchar, "user_agent" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_758836b4f0"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_sessions_on_user_id" ON "sessions" ("user_id") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "articles" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "title" varchar NOT NULL, "slug" varchar NOT NULL, "current_revision_id" integer, "created_by_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "starts_at" datetime(6) /*application='TeamWiki'*/, "starts_precision" varchar /*application='TeamWiki'*/, "ends_at" datetime(6) /*application='TeamWiki'*/, "ends_precision" varchar /*application='TeamWiki'*/, "kind" varchar /*application='TeamWiki'*/, "status" varchar DEFAULT 'stub' NOT NULL /*application='TeamWiki'*/, "comments_count" integer DEFAULT 0 NOT NULL /*application='TeamWiki'*/, "lock_version" integer DEFAULT 0 NOT NULL /*application='TeamWiki'*/, "likes_count" integer DEFAULT 0 NOT NULL /*application='TeamWiki'*/, CONSTRAINT "fk_rails_af73c24fa7"
FOREIGN KEY ("created_by_id")
  REFERENCES "users" ("id")
);
CREATE TABLE IF NOT EXISTS "tags" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "slug" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_tags_on_name" ON "tags" ("name") /*application='TeamWiki'*/;
CREATE UNIQUE INDEX "index_tags_on_slug" ON "tags" ("slug") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "taggings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "tag_id" integer NOT NULL, "taggable_type" varchar NOT NULL, "taggable_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_9fcd2e236b"
FOREIGN KEY ("tag_id")
  REFERENCES "tags" ("id")
);
CREATE INDEX "index_taggings_on_taggable" ON "taggings" ("taggable_type", "taggable_id") /*application='TeamWiki'*/;
CREATE UNIQUE INDEX "index_taggings_uniqueness" ON "taggings" ("tag_id", "taggable_type", "taggable_id") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "active_storage_blobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "filename" varchar NOT NULL, "content_type" varchar, "metadata" text, "service_name" varchar NOT NULL, "byte_size" bigint NOT NULL, "checksum" varchar, "created_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_active_storage_blobs_on_key" ON "active_storage_blobs" ("key") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "active_storage_attachments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "record_type" varchar NOT NULL, "record_id" bigint NOT NULL, "blob_id" bigint NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c3b3935057"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE INDEX "index_active_storage_attachments_on_blob_id" ON "active_storage_attachments" ("blob_id") /*application='TeamWiki'*/;
CREATE UNIQUE INDEX "index_active_storage_attachments_uniqueness" ON "active_storage_attachments" ("record_type", "record_id", "name", "blob_id") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "active_storage_variant_records" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "blob_id" bigint NOT NULL, "variation_digest" varchar NOT NULL, CONSTRAINT "fk_rails_993965df05"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE UNIQUE INDEX "index_active_storage_variant_records_uniqueness" ON "active_storage_variant_records" ("blob_id", "variation_digest") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "uploads" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_15d41e668d"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_uploads_on_user_id" ON "uploads" ("user_id") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "activities" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "action" varchar NOT NULL, "subject_type" varchar, "subject_id" integer, "subject_label" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "likes_count" integer DEFAULT 0 NOT NULL /*application='TeamWiki'*/, CONSTRAINT "fk_rails_7e11bb717f"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_activities_on_user_id" ON "activities" ("user_id") /*application='TeamWiki'*/;
CREATE INDEX "index_activities_on_subject" ON "activities" ("subject_type", "subject_id") /*application='TeamWiki'*/;
CREATE INDEX "index_activities_on_created_at" ON "activities" ("created_at") /*application='TeamWiki'*/;
CREATE UNIQUE INDEX "index_articles_on_slug" ON "articles" ("slug") /*application='TeamWiki'*/;
CREATE UNIQUE INDEX "index_articles_on_title" ON "articles" ("title") /*application='TeamWiki'*/;
CREATE INDEX "index_articles_on_created_by_id" ON "articles" ("created_by_id") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "revisions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "article_id" integer NOT NULL, "author_id" integer NOT NULL, "body" text DEFAULT '' NOT NULL, "edit_summary" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_f61b4224ec"
FOREIGN KEY ("author_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_c79eeb35e6"
FOREIGN KEY ("article_id")
  REFERENCES "articles" ("id")
);
CREATE INDEX "index_revisions_on_author_id" ON "revisions" ("author_id") /*application='TeamWiki'*/;
CREATE INDEX "index_revisions_on_article_id" ON "revisions" ("article_id") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "links" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "source_article_id" integer NOT NULL, "target_title" varchar NOT NULL, "target_article_id" integer, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_d87229375d"
FOREIGN KEY ("source_article_id")
  REFERENCES "articles" ("id")
);
CREATE INDEX "index_links_on_target_title" ON "links" ("target_title") /*application='TeamWiki'*/;
CREATE UNIQUE INDEX "index_links_on_source_article_id_and_target_title" ON "links" ("source_article_id", "target_title") /*application='TeamWiki'*/;
CREATE INDEX "index_links_on_target_article_id" ON "links" ("target_article_id") /*application='TeamWiki'*/;
CREATE INDEX "index_articles_on_starts_at" ON "articles" ("starts_at") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "users" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "email_address" varchar NOT NULL, "password_digest" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "name" varchar, "provider" varchar, "uid" varchar, "avatar_url" varchar, "role" varchar DEFAULT 'editor' NOT NULL /*application='TeamWiki'*/, "last_seen_at" datetime(6) /*application='TeamWiki'*/, "bio" varchar /*application='TeamWiki'*/, "notifications_seen_at" datetime(6) /*application='TeamWiki'*/);
CREATE UNIQUE INDEX "index_users_on_email_address" ON "users" ("email_address") /*application='TeamWiki'*/;
CREATE UNIQUE INDEX "index_users_on_provider_and_uid" ON "users" ("provider", "uid") /*application='TeamWiki'*/;
CREATE INDEX "index_articles_on_kind" ON "articles" ("kind") /*application='TeamWiki'*/;
CREATE INDEX "index_articles_on_status" ON "articles" ("status") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "site_settings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "brand_name" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "about" text /*application='TeamWiki'*/, "footer" text /*application='TeamWiki'*/, "tagline" varchar /*application='TeamWiki'*/, "home_heading" varchar /*application='TeamWiki'*/);
CREATE TABLE IF NOT EXISTS "citations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "article_id" integer NOT NULL, "material_id" integer, "material_handle" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_84cc954437"
FOREIGN KEY ("article_id")
  REFERENCES "articles" ("id")
, CONSTRAINT "fk_rails_53a173619b"
FOREIGN KEY ("material_id")
  REFERENCES "materials" ("id")
);
CREATE INDEX "index_citations_on_material_id" ON "citations" ("material_id") /*application='TeamWiki'*/;
CREATE UNIQUE INDEX "index_citations_on_article_id_and_material_handle" ON "citations" ("article_id", "material_handle") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "comments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "commentable_type" varchar NOT NULL, "commentable_id" integer NOT NULL, "author_id" integer NOT NULL, "body" text NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "likes_count" integer DEFAULT 0 NOT NULL /*application='TeamWiki'*/, CONSTRAINT "fk_rails_f44b1e3c8a"
FOREIGN KEY ("author_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_comments_on_commentable" ON "comments" ("commentable_type", "commentable_id") /*application='TeamWiki'*/;
CREATE INDEX "index_comments_on_author_id" ON "comments" ("author_id") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "materials" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "title" varchar NOT NULL, "description" text, "url" varchar, "user_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "slug" varchar NOT NULL, "source" varchar, "author" varchar, "published_at" datetime(6), "published_precision" varchar, "confidence" varchar DEFAULT 'unconfirmed' NOT NULL, "rights" varchar, "comments_count" integer DEFAULT 0 NOT NULL, "isbn" varchar /*application='TeamWiki'*/, "pages" varchar /*application='TeamWiki'*/, "publisher" varchar /*application='TeamWiki'*/, "volume" varchar /*application='TeamWiki'*/, "file_created_at" datetime(6) /*application='TeamWiki'*/, "page_count" integer /*application='TeamWiki'*/, "ownership" varchar /*application='TeamWiki'*/, "kind" varchar /*application='TeamWiki'*/, "likes_count" integer DEFAULT 0 NOT NULL /*application='TeamWiki'*/, CONSTRAINT "fk_rails_cf58c42728"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_materials_on_user_id" ON "materials" ("user_id") /*application='TeamWiki'*/;
CREATE UNIQUE INDEX "index_materials_on_slug" ON "materials" ("slug") /*application='TeamWiki'*/;
CREATE INDEX "index_materials_on_confidence" ON "materials" ("confidence") /*application='TeamWiki'*/;
CREATE INDEX "index_materials_on_rights" ON "materials" ("rights") /*application='TeamWiki'*/;
CREATE INDEX "index_articles_on_updated_at" ON "articles" ("updated_at") /*application='TeamWiki'*/;
CREATE INDEX "index_materials_on_published_at" ON "materials" ("published_at") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "transcription_revisions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "transcription_id" integer NOT NULL, "author_id" integer NOT NULL, "body" text NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1ab7f99b31"
FOREIGN KEY ("transcription_id")
  REFERENCES "transcriptions" ("id")
, CONSTRAINT "fk_rails_2c726c4219"
FOREIGN KEY ("author_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_transcription_revisions_on_transcription_id" ON "transcription_revisions" ("transcription_id") /*application='TeamWiki'*/;
CREATE INDEX "index_transcription_revisions_on_author_id" ON "transcription_revisions" ("author_id") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "stat_snapshots" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "date" date NOT NULL, "articles_count" integer DEFAULT 0 NOT NULL, "materials_count" integer DEFAULT 0 NOT NULL, "unconfirmed_materials_count" integer DEFAULT 0 NOT NULL, "transcribed_chars" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "total_file_bytes" integer /*application='TeamWiki'*/, "total_pages" integer /*application='TeamWiki'*/);
CREATE UNIQUE INDEX "index_stat_snapshots_on_date" ON "stat_snapshots" ("date") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "transcriptions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "material_id" integer NOT NULL, "author_id" integer NOT NULL, "body" text, "status" varchar DEFAULT 'drafting' NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "creation_method" varchar, "ai_service" varchar, "ai_model" varchar, "label" varchar, "position" integer DEFAULT 1 NOT NULL, "assignee_id" integer, "lock_version" integer DEFAULT 0 NOT NULL /*application='TeamWiki'*/, "likes_count" integer DEFAULT 0 NOT NULL /*application='TeamWiki'*/, CONSTRAINT "fk_rails_65bda5c3c8"
FOREIGN KEY ("author_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_f9cd278d13"
FOREIGN KEY ("material_id")
  REFERENCES "materials" ("id")
, CONSTRAINT "fk_rails_316fe84470"
FOREIGN KEY ("assignee_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_transcriptions_on_author_id" ON "transcriptions" ("author_id") /*application='TeamWiki'*/;
CREATE INDEX "index_transcriptions_on_assignee_id" ON "transcriptions" ("assignee_id") /*application='TeamWiki'*/;
CREATE INDEX "index_transcriptions_on_material_id" ON "transcriptions" ("material_id") /*application='TeamWiki'*/;
CREATE INDEX "index_materials_on_ownership" ON "materials" ("ownership") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "publications" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "title" varchar NOT NULL, "kind" varchar NOT NULL, "released_at" datetime(6), "released_precision" varchar, "sales_status" varchar DEFAULT 'on_sale' NOT NULL, "store_url" varchar, "registered_by_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "likes_count" integer DEFAULT 0 NOT NULL /*application='TeamWiki'*/, CONSTRAINT "fk_rails_f27978daaf"
FOREIGN KEY ("registered_by_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_publications_on_registered_by_id" ON "publications" ("registered_by_id") /*application='TeamWiki'*/;
CREATE INDEX "index_publications_on_released_at" ON "publications" ("released_at") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "likes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "reactor_id" integer NOT NULL, "reactable_type" varchar NOT NULL, "reactable_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_215a928589"
FOREIGN KEY ("reactor_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_likes_on_reactable" ON "likes" ("reactable_type", "reactable_id") /*application='TeamWiki'*/;
CREATE UNIQUE INDEX "index_likes_uniqueness" ON "likes" ("reactor_id", "reactable_type", "reactable_id") /*application='TeamWiki'*/;
CREATE TABLE IF NOT EXISTS "notifications" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "recipient_id" integer NOT NULL, "actor_id" integer NOT NULL, "kind" varchar NOT NULL, "subject_type" varchar NOT NULL, "subject_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_4aea6afa11"
FOREIGN KEY ("recipient_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_06a39bb8cc"
FOREIGN KEY ("actor_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_notifications_on_actor_id" ON "notifications" ("actor_id") /*application='TeamWiki'*/;
CREATE INDEX "index_notifications_on_subject" ON "notifications" ("subject_type", "subject_id") /*application='TeamWiki'*/;
CREATE INDEX "index_notifications_on_recipient_id_and_created_at" ON "notifications" ("recipient_id", "created_at") /*application='TeamWiki'*/;
CREATE INDEX "index_articles_on_current_revision_id" ON "articles" ("current_revision_id") /*application='TeamWiki'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20260726080655'),
('20260718010000'),
('20260718000002'),
('20260718000001'),
('20260718000000'),
('20260717000000'),
('20260715115913'),
('20260711103934'),
('20260624162804'),
('20260620084722'),
('20260617143929'),
('20260617130453'),
('20260616235749'),
('20260615150937'),
('20260613084507'),
('20260613083355'),
('20260612033907'),
('20260612003419'),
('20260611222940'),
('20260611062524'),
('20260610110020'),
('20260609162232'),
('20260609162228'),
('20260609162226'),
('20260609145532'),
('20260609145530'),
('20260609103809'),
('20260608062949'),
('20260607235553'),
('20260607041941'),
('20260607041204'),
('20260607000052'),
('20260606171721'),
('20260606044940'),
('20260606022514'),
('20260605013549'),
('20260603080000'),
('20260603073335'),
('20260602132724'),
('20260602083625'),
('20260602070646'),
('20260602055255'),
('20260602040134'),
('20260602011246'),
('20260601135837'),
('20260601135822'),
('20260601134626'),
('20260601134510'),
('20260601134509'),
('20260601134313'),
('20260601134312'),
('20260601134046'),
('20260601134022'),
('20260601134021');

