# 資料作成後の後処理（非同期）。create からのみ enqueue される。
# ファイル資料は同一プロセス内で逐次に
#   ① メタデータ抽出（file_created_at / page_count + 助言コメント）
#   ② PDF の linearize（blob 差し替え）
# を行う（逐次実行で blob 差し替えと抽出読み取りの競合を避ける。②の再 attach は再トリガしない）。
# URL 資料は外部サイトの API/og:title でタイトル・発行日を補完する。
# いずれも外部 I/O・重い処理をリクエストから外すのが目的。
class MaterialPostProcessJob < ApplicationJob
  queue_as :default

  def perform(material)
    if material.file.attached?
      extract_metadata(material)
      material.linearize_file!
    elsif material.url.present?
      autofill_link_metadata(material)
    end
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

  # URL 資料のメタデータ補完。動画サイトの API → だめなら og:title でタイトルを、
  # 動画サイトの公開日で発行日（day 精度）を埋める。
  # title は「未記入＝ensure_title が url を入れた状態」のときだけ上書きし、ユーザ入力は尊重する。
  # 補える項目が無ければ外部取得自体を省く。失敗は原本に影響させずログのみ。
  def autofill_link_metadata(material)
    needs_title = material.title.blank? || material.title == material.url
    needs_date  = material.published_at.nil?
    return unless needs_title || needs_date

    video = VideoMetadata.call(material.url)
    if needs_title
      title = video&.dig(:title) || OgTitleFetcher.call(material.url)
      material.update_column(:title, title) if title.present?
    end
    if needs_date && (date = video&.dig(:published_on))
      material.update_columns(published_at: date.in_time_zone, published_precision: "day")
    end
  rescue StandardError => e
    Rails.logger.warn("autofill_link_metadata failed for Material##{material.id}: #{e.class}: #{e.message}")
  end
end
