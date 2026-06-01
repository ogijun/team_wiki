# team_wiki 引き継ぎドキュメント

最終更新: 2026-06-02 / ブランチ: `main`（`feature/wiki-core` をマージ済み・削除済み）

少人数チーム向けの Rails wiki。Markdown 投稿・タグ・`[[相互リンク]]`+バックリンク・編集履歴・
メディアアップロードを備えた MVP が動作する状態。

---

## 1. 現状サマリ

- **テスト**: `bin/rails test` → 63 runs / 148 assertions / 0 failures（全グリーン）
- **DB**: SQLite。マイグレーション適用済み（`bin/rails db:migrate` 済み）
- **git**: `main` に全機能マージ済み。**リモート未設定**（GitHub リポジトリは未作成）
- **設計/計画ドキュメント**: `docs/superpowers/specs/` と `docs/superpowers/plans/` にローカル保存。
  `.gitignore` で `/docs/superpowers/` を除外しているため未コミット（参照用）

## 2. 起動方法

```bash
cd team_wiki
bin/rails server          # http://localhost:3000
bin/rails test            # テスト一括実行
bin/rails console
```

> 注: ログインシェルに `rails` を上書きする zsh 関数があり、素の `rails` は使えない。
> プロジェクト直下の `bin/rails`（binstub）を使うこと。新規 `rails new` 等が必要な場合のみ
> `command rails ...` で関数を回避する。

## 3. アーキテクチャ（設計原則: State > Coupling > Complexity > Code）

- **本文はリビジョンにのみ存在**。`pages` はメタデータ（title/slug/current_revision_id）だけを持ち、
  本文は `revisions.body` に全履歴を追記保存。「現在のページ = current_revision」が単一の真実。
  → 状態の重複ゼロ。差分・復元は「リビジョンを並べる／旧本文で新リビジョンを作る」だけ。
- **バックリンク・タグ参照は導出インデックス**。正本（Markdown 本文）から保存時に再生成する
  キャッシュ。`links` テーブルが `[[リンク]]` の解決結果を保持。
- **書き込みは `PageRevisionCreator` 一点集約**。リビジョン作成 → current 更新 → links 再生成 →
  taggings 同期 → 赤リンク埋め戻しを1トランザクションで実行。将来のフック（検索 index 更新・通知）は
  ここに足す。
- **サービスはステートレス**（`module_function` / 引数で全受け取り）。

## 4. データモデル

| モデル | 役割 | 主なカラム/関連 |
|---|---|---|
| `User` | 認証ユーザー | email_address, password_digest, name |
| `Session` | ログインセッション | Rails 8 認証ジェネレータ生成 |
| `Page` | ページ同一性・メタ | title(uniq), slug(uniq), current_revision_id, created_by。`to_param=slug` |
| `Revision` | 本文の1版（追記のみ） | page, author, body, edit_summary |
| `Tag` / `Tagging` | タグ（**ポリモーフィック**） | Tagging は taggable_type/taggable_id。将来ページ以外にも付与可 |
| `Link` | `[[リンク]]` 導出インデックス | source_page, target_title, target_page_id(null=赤リンク) |
| `Upload` | メディア（ActiveStorage） | user, has_one_attached :file。型・サイズ検証 |

- slug は日本語を保持する独自 `Slug.slugify`（`app/lib/slug.rb`）。`parameterize` は日本語を消すため不使用。
- 赤リンク = `links.target_page_id` が null。同名タイトルのページ作成時に
  `PageRevisionCreator#backfill_inbound_links` が埋め戻す。

## 5. 主要ファイル

```
app/lib/slug.rb                          # 日本語対応 slugify（純関数）
app/services/wiki_link_extractor.rb      # 本文 → [[タイトル]] 配列（純関数, PATTERN 定数を共有）
app/services/markdown_renderer.rb        # commonmarker(GFM) + [[]] 解決 + サニタイズ
app/services/wiki_link_resolver.rb       # title → {href, exists}。renderer に注入
app/services/page_revision_creator.rb    # 唯一の書き込み経路
app/controllers/pages_controller.rb      # CRUD
app/controllers/revisions_controller.rb  # 履歴・差分(diffy)・復元
app/controllers/tags_controller.rb       # タグ一覧・絞り込み
app/controllers/search_controller.rb     # タイトル/本文 LIKE 検索
app/controllers/uploads_controller.rb    # メディアアップロード(JSON で URL 返却)
app/javascript/controllers/editor_controller.js  # toast-ui エディタ初期化・画像アップロード連携
config/routes.rb                         # ルート定義
```

認証必須化は `app/controllers/concerns/authentication.rb` の `before_action :require_authentication`
（ApplicationController が include）。未ログインは `new_session_path` にリダイレクト。
サインアップは `RegistrationsController`（v1 オープン）。

## 6. 既知の制約 / 未確認

- **手動ブラウザ確認が未実施**: toast-ui の Markdown⇄WYSIWYG 切替と画像ドラッグ&ドロップの実機挙動は
  ヘッドレス検証のみ未到達。`bin/rails server` でログイン→新規ページ編集で確認すること。
- コードフェンス内の `[[ ]]` も linkify される（v1 許容）。
- 全文検索は LIKE 実装（FTS5 は後付け）。
- ページタイトルの **rename 非対応**（slug 生成は作成時のみ。リネームすると既存リンクの再解決は未実装）。
- toast-ui は CDN 読み込み（`app/views/layouts/application.html.erb`）。オフライン/CSP 厳格化時は
  importmap or vendoring に切替が必要。
- `Upload` の URL は `url_for`。本番では `config.action_controller.default_url_options`（host）設定が必要。

## 7. 次にやるとよいこと（拡張余地）

1. **ページ rename 対応**: title 変更時に slug 再生成 or 固定、`links.target_title` の再解決。
2. **全文検索を FTS5 へ**: `revisions` 本文の virtual table。書き込みフックは PageRevisionCreator に追加。
3. **公開閲覧 / 権限ロール**: 現状は閲覧もログイン必須。read-only 公開や admin ロールを足す余地。
4. **招待制サインアップ**: 現状オープン。`RegistrationsController` を絞る。
5. **本番デプロイ**: SQLite 単一ファイル運用。Kamal 設定（`config/deploy.yml`）が scaffold 済み。
   ActiveStorage の保存先と host 設定を本番向けに。
6. **グラフビュー / 名前空間 / カテゴリ**: 導出インデックス（links）とポリモーフィック tagging を活かす。

## 8. このリポジトリの作業規約

- コミットは `git add <個別パス>`（`git add -A`/`.` 禁止）。1 論理単位 = 1 コミット。
- `docs/superpowers/` 配下はコミットしない（ローカル参照用、`.gitignore` 済み）。
- ブランチ名はチケット番号なしの `feature/descriptive-name`。
- コミットメッセージに attribution は付けない。
- 新機能は TDD（RED → GREEN → コミット）。
