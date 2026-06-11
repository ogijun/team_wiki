# litestream-ruby の設定。
#
# 認証情報・エンドポイントは Kamal の env（.kamal/secrets → コンテナ ENV）で注入し、
# config/litestream.yml 内の $LITESTREAM_* がそれを直接展開する。よってここで
# config.litestream.* を設定する必要はなく、ENV 不在の dev/test/CI/プリコンパイルでは
# 何も起きない（安全な no-op）。実際の起動ガードは config/puma.rb 側にある。
#
# 必要な ENV（R2＝S3 互換）:
#   LITESTREAM_REPLICA_BUCKET    … バケット名
#   LITESTREAM_REPLICA_ENDPOINT  … https://<account_id>.r2.cloudflarestorage.com
#   LITESTREAM_REPLICA_REGION    … R2 では無視されるが S3 クライアントが要求（慣例で auto）
#   LITESTREAM_ACCESS_KEY_ID     … R2 アクセスキー ID
#   LITESTREAM_SECRET_ACCESS_KEY … R2 シークレットアクセスキー
#
# Litestream ダッシュボード（Litestream::Engine）は今は未マウント。
