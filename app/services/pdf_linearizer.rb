require "open3"

# qpdf による PDF の linearize（Web表示用に並べ替える可逆処理）。
# 失敗・非対応・qpdf 不在はすべて安全側（nil / false）に倒す（raise しない）。
module PdfLinearizer
  module_function

  # linearize 済みか。linearized PDF は線形化辞書 /Linearized をファイル先頭の最初の
  # オブジェクトに置くため、先頭チャンクのバイト走査で判定できる（qpdf 起動不要・高速）。
  def linearized?(path)
    File.binread(path, 2048).include?("/Linearized")
  rescue StandardError
    false
  end

  # qpdf --linearize で最適化版を一時ファイルに作る。成功で出力パス、失敗で nil。
  # qpdf の exit: 0=成功 / 3=警告ありだが出力済み / 2=エラー。0,3 を成功扱いにする。
  def linearize(in_path)
    out_path = File.join(Dir.tmpdir, "linearized-#{SecureRandom.hex(8)}.pdf")
    _out, _err, status = Open3.capture3("qpdf", "--linearize", in_path, out_path)
    return out_path if [ 0, 3 ].include?(status.exitstatus) && File.size?(out_path)

    File.unlink(out_path) if File.exist?(out_path)
    nil
  rescue StandardError
    nil
  end
end
