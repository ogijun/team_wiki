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

- **secret**（`.kamal/secrets`）: `RAILS_MASTER_KEY`、Discord 各種（`DISCORD_CLIENT_ID` / `DISCORD_CLIENT_SECRET` / `DISCORD_GUILD_ID` / `DISCORD_REQUIRED_ROLE_ID` / `DISCORD_ADMIN_ROLE_ID`）
- **clear**（`config/deploy.yml`）: `APP_BASE_URL` など

```bash
bin/kamal setup    # 初回（以降は bin/kamal deploy）
```

### ストレージ

`config/active_storage.service` は `ACTIVE_STORAGE_SERVICE`（ENV）で選択し、既定はローカル Disk。
Kamal の永続ボリューム（`/rails/storage`）に保存されるためデプロイをまたいでも残る。

オブジェクトストレージに移す場合は、`config/storage.yml` にサービスを追加し（R2 などの S3 互換）、`ACTIVE_STORAGE_SERVICE` を設定、対応するシークレット（`R2_ENDPOINT` / `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` 等）を `.kamal/secrets` と `config/deploy.yml` の env に追加する。Active Storage の blob キーは保存先非依存なので、移行はキーを保ったまま実体をコピーして `service_name` を更新するだけでよい。

## ライセンス

[GNU Affero General Public License v3.0](LICENSE)（AGPL-3.0）の下で公開している。ネットワーク越しに利用させる場合も、改変版のソース提供義務が及ぶ点に注意。
