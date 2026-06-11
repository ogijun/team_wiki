# Team Wiki

[![CI](https://github.com/ogijun/team_wiki/actions/workflows/ci.yml/badge.svg)](https://github.com/ogijun/team_wiki/actions/workflows/ci.yml)

記事・資料をチームで編集する Wiki アプリケーション。
Discord サーバーのメンバー（特定ロール保持者）だけがログインして閲覧・編集できる。

汎用的な Wiki 基盤として作られており、個別の用途（特定テーマのデータベース等）はこのアプリの応用例として運用する。

## 主な機能

- **記事 (Article)** — Markdown 本文、リビジョン履歴と版間差分、貢献者表示。種別（作品/人物/出来事）と編集状態（スタブ/執筆中/完成）。
- **資料 (Material)** — ファイル添付または URL（YouTube 等の埋め込み対応）。書誌情報（著者・出典元・発行日）、信頼度（原本確認済/未確認）・権利状態、画像/YouTube のサムネイル。登録後はファイル/URL の差し替え不可（履歴性のため）。新規登録すると、その資料を引用するスタブ記事が自動で1本作られる。
- **文字起こし (Transcription)** — メディア資料（画像/動画/音声/PDF）に手動の文字起こしを 1 件ずつ紐づけ、未着手 / 作業中 / 完了 の進捗を管理（`/transcriptions` ダッシュボード）。作成手法（手書き / AI / AI＋人手修正、AI の場合はサービス・モデル名）も記録できる。
- **コメント** — 記事・資料に複数コメント（プレーンテキスト）を投稿。新規作成時の「最初のコメント」も含む。各一覧に件数（💬）を表示し、投稿はアクティビティに記録。削除は投稿者本人または admin のみ。
- **引用** — 本文中の `[[ref:<slug>]]` で資料を脚注として参照。書誌情報を使った体裁で出典一覧を生成。引用は保存時に永続化され、資料側から「引用している記事」を逆引きできる（記事と資料は引用を介した多対多）。
- **Wiki リンク** — 本文中の `[[記事タイトル]]` で記事間リンク（未作成リンクは赤表示）。
- **タグ / 検索 / 年表 (chronicle)** — タグ分類、検索、あいまい日付（年だけ等）対応の年表表示。
- **アクティビティ** — 作成・編集・削除のタイムライン。
- **ユーザーと権限** — プロフィール・アバター・アカウント設定。ロールは Discord ロールから判定（editor / admin）。admin はメンバー管理や資料の信頼度確定が可能。
- **サイト設定（管理者）** — ブランド名・ロゴ・アプリアイコン（favicon / apple-touch）・「このサイトについて」ページ・全ページ共通フッタを管理画面から編集。

## 技術スタック

- Ruby 4.0.5（`mise` 管理） / Rails 8.1
- SQLite + Propshaft + importmap-rails
- Hotwire（Turbo / Stimulus）、Markdown は commonmarker、ページングは pagy
- 認証: Discord OAuth（omniauth-discord） — 特定サーバー所属＋ロールでゲート
- ストレージ: Active Storage。保存先は `ACTIVE_STORAGE_SERVICE` で選択（既定はローカル Disk。R2 等の S3 互換へ切替可）。サムネ生成に image_processing（libvips）
- ジョブ/キャッシュ: Solid Queue / Solid Cache / Solid Cable
- デプロイ: Kamal + Docker

## セットアップ（開発）

```bash
mise install                 # Ruby 4.0.5
bundle install
bin/rails db:prepare         # スキーマ作成
cp .env.example .env         # 環境変数を用意（下記）
bin/dev                      # 開発サーバー起動
```

テスト:

```bash
bin/rails test
```

### 環境変数（`.env`、dev/test のみ dotenv-rails が読み込む）

Discord ログインを実際に通すには `.env` に以下を設定する。
未設定でも初期化子のデフォルト（`test-*`）で起動はできるが、ログインは成立しない。

| 変数 | 用途 |
|---|---|
| `DISCORD_CLIENT_ID` / `DISCORD_CLIENT_SECRET` | Discord アプリの OAuth2 認証情報 |
| `DISCORD_GUILD_ID` | ログインを許可するサーバー（ギルド）ID |
| `DISCORD_REQUIRED_ROLE_ID` | 必須ロール ID（このロール保持者のみ許可）。カンマ区切りで複数指定可（いずれか1つでも保持していれば許可）例: `111,222` |
| `DISCORD_ADMIN_ROLE_ID` | admin ロール ID（任意。保持者を admin に昇格。未設定だと全員 editor）。同じくカンマ区切りで複数可（いずれか該当で admin） |
| `APP_BASE_URL` | redirect_uri を固定（例: `http://team-wiki.test`）。Discord 側に登録したコールバックと scheme/host を一致させる |

> Discord 開発者ポータルのリダイレクト URI には `<APP_BASE_URL>/auth/discord/callback` をフルパスで登録する。

### ローカルドメイン（任意）

ポート番号を隠して `.test` ドメインで動かすため、[puma-dev](https://github.com/puma/puma-dev) を使うとよい。
macOS で `.test` の名前解決が効かない場合は `/etc/hosts` に `127.0.0.1 <任意のホスト>.test` を追加する。

## デプロイ

Kamal でコンテナデプロイする。デプロイ設定はインスタンス固有のため `config/deploy.yml` は
gitignore してあり、テンプレートの `config/deploy.sample.yml` をコピーして自分の値（ホスト名・
サーバ・レジストリ等）を埋める。

```bash
cp config/deploy.sample.yml config/deploy.yml   # 自分の値に編集
```

シークレットは `.kamal/secrets`（1Password 等から取得）経由で注入。

- **secret**（`.kamal/secrets`）: `RAILS_MASTER_KEY`、Discord 各種（`DISCORD_CLIENT_ID` / `DISCORD_CLIENT_SECRET` / `DISCORD_GUILD_ID` / `DISCORD_REQUIRED_ROLE_ID` / `DISCORD_ADMIN_ROLE_ID`）。任意で litestream の `LITESTREAM_*`（[バックアップ](#バックアップ)参照）
- **clear**（`config/deploy.yml`）: `APP_BASE_URL` など

```bash
bin/kamal setup    # 初回（以降は bin/kamal deploy）
```

### ストレージ

`config/active_storage.service` は `ACTIVE_STORAGE_SERVICE`（ENV）で選択し、既定はローカル Disk。
Kamal の永続ボリューム（`/rails/storage`）に保存されるためデプロイをまたいでも残る。

オブジェクトストレージに移す場合は、`config/storage.yml` にサービスを追加し（R2 などの S3 互換。既に `r2` を定義済み）、対応するシークレット（`R2_ENDPOINT` / `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` 等）を `.kamal/secrets` と `config/deploy.yml` の env に用意する。Active Storage の blob キーは保存先非依存なので、移行はキーを保ったまま実体をコピーして `service_name` を更新するだけでよい。

`local` → `r2` への移行手順（冪等・チェックサム検証つきの `StorageMigrator` を使う）:

1. 投稿・編集を一時停止し、blob が増えない状態にする。
2. 本番コンテナで移行を流す（実体をコピーするだけで元ファイルは消さない）。
   ```sh
   bin/kamal app exec --reuse 'bin/rails storage:migrate FROM=local TO=r2'
   ```
   1件失敗しても全体は止めず、最後に失敗一覧を出して非ゼロ終了する。再実行すれば既存キーは skip される。
3. `config/deploy.yml`（インスタンス側）の env に `ACTIVE_STORAGE_SERVICE=r2` と `R2_*` シークレットを設定し、`bin/kamal deploy` する。
4. 添付・サムネイル（variant）が表示されることを確認する。variant も blob 行として一緒に移行・再生成されるため個別対応は不要。
5. 元の `local`（Disk）の実体はそのまま残るので、問題があれば `ACTIVE_STORAGE_SERVICE` を `local` に戻すだけで切り戻せる。安定後に手動で削除する。

### バックアップ

本番は単一 VPS の SQLite なので、[litestream](https://litestream.io/) で本体 DB（`storage/production.sqlite3`）の WAL を Cloudflare R2 へ継続ストリーミングする。Puma 配下で動き（`config/puma.rb`）、複製対象は `config/litestream.yml`。cache/queue/cable は Solid 系の再生成可能な状態なので複製しない。

`LITESTREAM_REPLICA_BUCKET` が注入された本番でのみ複製プロセスが起動する。未設定（dev/test/CI/アセットプリコンパイル）では何も起きない。必要な ENV は次の通りで、`.kamal/secrets` と `config/deploy.yml` の env に追加する（R2＝S3 互換、endpoint は `https://<account_id>.r2.cloudflarestorage.com`）。

| 変数 | 用途 |
|---|---|
| `LITESTREAM_REPLICA_BUCKET` | 複製先 R2 バケット名 |
| `LITESTREAM_REPLICA_ENDPOINT` | R2 エンドポイント URL |
| `LITESTREAM_REPLICA_REGION` | R2 では無視されるが S3 クライアントが要求（慣例で `auto`） |
| `LITESTREAM_ACCESS_KEY_ID` / `LITESTREAM_SECRET_ACCESS_KEY` | R2 アクセスキー |

リストア（復元演習）はコンテナ内で次を実行する。`--database` には `config/litestream.yml` の `path` と一致する値を渡す。

```bash
# 既存 DB は退避してから（rails が再生成すると "output path already exists" になる）
bin/rails litestream:restore -- --database=storage/production.sqlite3
```

レプリカの状態は `bin/rails litestream:databases` / `litestream:snapshots -- --database=...` で確認できる。

> **リストア演習を一度やるまではバックアップは存在しないのと同じ。** 復元手順を実際に通して中身を確認するまで、バックアップが取れている保証はないものとして扱う。

## ライセンス

[GNU Affero General Public License v3.0](LICENSE)（AGPL-3.0）の下で公開している。ネットワーク越しに利用させる場合も、改変版のソース提供義務が及ぶ点に注意。
