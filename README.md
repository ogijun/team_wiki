# Team Wiki

記事・資料をチームで編集する Wiki アプリケーション。
Discord サーバーのメンバー（特定ロール保持者）だけがログインして閲覧・編集できる。

汎用的な Wiki 基盤として作られており、個別の用途（特定テーマのデータベース等）はこのアプリの応用例として運用する。

## 主な機能

- **記事 (Article)** — Markdown 本文、リビジョン履歴と版間差分、貢献者表示。種別（作品/人物/出来事）と編集状態（スタブ/執筆中/完成）。
- **資料 (Material)** — ファイル添付または URL（YouTube 等の埋め込み対応）。書誌情報（著者・出典元・発行日・取得日）、画像/YouTube のサムネイル。
- **引用** — 本文中の `[[ref:<slug>]]` で資料を脚注として参照。書誌情報を使った体裁で出典一覧を生成。
- **Wiki リンク** — 本文中の `[[記事タイトル]]` で記事間リンク（未作成リンクは赤表示）。
- **タグ / 検索 / 年表 (chronicle)** — タグ分類、全文検索、あいまい日付（年だけ等）対応の年表表示。
- **アクティビティ** — 作成・編集・削除のタイムライン。
- **ユーザー** — プロフィール、アバター、アカウント設定。

## 技術スタック

- Ruby 4.0.1（`mise` 管理） / Rails 8.1
- SQLite + Propshaft + importmap-rails
- Hotwire（Turbo / Stimulus）、Markdown は commonmarker、ページングは pagy
- 認証: Discord OAuth（omniauth-discord） — 特定サーバー所属＋ロールでゲート
- ストレージ: Active Storage（dev/test = ローカルディスク、本番 = Cloudflare R2 / aws-sdk-s3）。サムネ生成に image_processing（libvips）
- ジョブ/キャッシュ: Solid Queue / Solid Cache / Solid Cable
- デプロイ: Kamal + Docker

## セットアップ（開発）

```bash
mise install                 # Ruby 4.0.1
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
| `DISCORD_REQUIRED_ROLE_ID` | 必須ロール ID（このロール保持者のみ許可） |
| `APP_BASE_URL` | redirect_uri を固定（例: `http://team-wiki.test`）。Discord 側に登録したコールバックと scheme/host を一致させる |

> Discord 開発者ポータルのリダイレクト URI には `<APP_BASE_URL>/auth/discord/callback` をフルパスで登録する。

### ローカルドメイン（任意）

ポート番号を隠して `.test` ドメインで動かすため、[puma-dev](https://github.com/puma/puma-dev) を使うとよい。
macOS で `.test` の名前解決が効かない場合は `/etc/hosts` に `127.0.0.1 <任意のホスト>.test` を追加する。

## デプロイ

Kamal でコンテナデプロイする。シークレットは `.kamal/secrets`（1Password から取得）経由で注入。

- **secret**（`.kamal/secrets`）: `RAILS_MASTER_KEY`, `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`
- **clear**（`config/deploy.yml`）: `R2_BUCKET` など

```bash
bin/kamal deploy
```

ストレージは Cloudflare R2（S3 互換）。`config/storage.yml` の `r2` サービスを使用し、aws-sdk-s3 のチェックサム設定（`when_required`）で R2 に対応している。
