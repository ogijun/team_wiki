namespace :materials do
  desc "既存 PDF の page_count を抽出して埋める（冪等）"
  task backfill_page_count: :environment do
    n = Material.backfill_page_counts!
    puts "page_count を #{n} 件の PDF 資料に補完しました。"
  end

  # generate_web_file! は失敗しても raise せずログに残して次へ進む（外部CLI契約）。
  # 成功件数だけでは取りこぼしに気づけないので、実行後に未生成の残数も出す。
  desc "既存PDFの軽量版（web_file）を生成する（未生成のみ・冪等）"
  task backfill_web_files: :environment do
    generated = Material.backfill_web_files!
    remaining = Material.with_attached_file.with_attached_web_file.count { |m| m.pdf? && !m.web_file.attached? }
    puts "#{generated} 件の PDF に軽量版を生成しました。"
    if remaining.positive?
      puts "未生成が #{remaining} 件残っています。Ghostscript の失敗が疑われるので、" \
           "ログの 'generate_web_file! failed' / 'PdfCompressor.compress failed' を確認してください。"
    end
  end

  desc "既存PDFを linearize する（未linearizeのみ・冪等）"
  task linearize_existing: :environment do
    changed = 0
    Material.with_attached_file.find_each do |m|
      next unless m.file.attached? && m.file.content_type == "application/pdf"
      before = m.file.blob.id
      m.linearize_file!
      changed += 1 if m.reload.file.blob.id != before
    end
    puts "#{changed} 件の PDF を linearize しました。"
  end
end
