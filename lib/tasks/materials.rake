namespace :materials do
  desc "既存 PDF の page_count を抽出して埋める（冪等）"
  task backfill_page_count: :environment do
    n = Material.backfill_page_counts!
    puts "page_count を #{n} 件の PDF 資料に補完しました。"
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
