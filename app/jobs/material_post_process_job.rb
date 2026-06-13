# アップロード後処理（非同期）。同一プロセス内で逐次に
#   ① メタデータ抽出（file_created_at / page_count + 助言コメント）
#   ② PDF の linearize（blob 差し替え）
# を行う。逐次実行により blob 差し替えと抽出読み取りの競合を避ける。
# create からのみ enqueue されるため、②の再 attach がジョブを再トリガすることはない。
class MaterialPostProcessJob < ApplicationJob
  queue_as :default

  def perform(material)
    return unless material.file.attached?

    extract_metadata(material)
    material.linearize_file!
  end

  private

  # ファイル由来メタデータの記録。日時はファイル作成日カラムへ、その他はコメントに候補列挙。
  # 作者は material.user（ジョブには Current.user が無いため）。失敗は原本に影響させずログのみ。
  def extract_metadata(material)
    result = MaterialMetadataExtractor.call(material)
    material.update_column(:file_created_at, result[:file_created_at]) if result[:file_created_at]
    material.update_column(:page_count, result[:page_count]) if result[:page_count]
    return if result[:details].empty?

    lines = result[:details].map { |label, value| "・#{label}: #{value}" }
    material.comments.create!(
      author: material.user,
      body: "📄 ファイルのメタデータから自動抽出した候補です（要確認）:\n#{lines.join("\n")}\n書誌情報の参考にどうぞ。"
    )
  rescue StandardError => e
    Rails.logger.warn("extract_metadata failed for Material##{material.id}: #{e.class}: #{e.message}")
  end
end
