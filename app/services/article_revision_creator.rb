# 移行用シム: ロジックは Article#revise! へ移動済み。呼び出し元を順次差し替えたら本ファイルを削除する。
module ArticleRevisionCreator
  module_function

  def call(article:, body:, author:, edit_summary: nil)
    article.revise!(body: body, author: author, edit_summary: edit_summary)
  end
end
