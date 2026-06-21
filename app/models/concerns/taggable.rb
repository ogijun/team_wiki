module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, as: :taggable, dependent: :destroy
    has_many :tags, through: :taggings

    attr_accessor :tag_names

    # tag_names が代入された save のときだけ同期（未代入=nil の save は既存タグを保つ）。
    # 空文字 "" が来たら tags=[] でクリアできる。
    before_validation :sync_tags, unless: -> { tag_names.nil? }
  end

  def sync_tags
    names = tag_names.to_s.split(/[,、]/).map(&:strip).reject(&:empty?).uniq
    self.tags = names.map { |name| find_or_create_tag(name) }
  end

  # 同時実行で同名タグが別リクエストに先に作られても拾えるよう、一意制約違反をリトライ吸収する
  # （tags.name は unique。find_or_create_by! の SELECT→INSERT の隙間で衝突しうる）。
  def find_or_create_tag(name)
    Tag.find_or_create_by!(name: name)
  rescue ActiveRecord::RecordNotUnique
    Tag.find_by!(name: name)
  end
end
