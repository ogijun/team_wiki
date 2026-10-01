# 入力中の日付をサーバ側の FuzzyTimestamp で読み取り、表示用ラベルを返す。
class FuzzyDatesController < ApplicationController
  def show
    return render plain: "" if params[:text].blank?

    value = FuzzyTimestamp.parse(params[:text], now: Time.current)
    render plain: FuzzyTimestamp.valid?(value) ? FuzzyTimestamp.label(value) : "読めない"
  end
end
