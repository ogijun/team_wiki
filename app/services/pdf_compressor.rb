require "open3"

# Ghostscript によるPDF表示用の軽量版生成。原本は変更しない。
module PdfCompressor
  module_function

  DPI = 144

  def compress(in_path)
    out_path = File.join(Dir.tmpdir, "compressed-#{SecureRandom.hex(8)}.pdf")
    _out, _err, status = Open3.capture3(
      "gs", "-sDEVICE=pdfwrite", "-dCompatibilityLevel=1.4", "-dPDFSETTINGS=/ebook",
      "-dColorImageResolution=#{DPI}", "-dGrayImageResolution=#{DPI}", "-dMonoImageResolution=#{DPI}",
      "-dNOPAUSE", "-dBATCH", "-sOutputFile=#{out_path}", in_path
    )
    return out_path if status.success? && File.size?(out_path)

    File.unlink(out_path) if File.exist?(out_path)
    nil
  rescue StandardError => error
    Rails.logger.warn("PdfCompressor.compress failed: #{error.class}: #{error.message}")
    nil
  end
end
