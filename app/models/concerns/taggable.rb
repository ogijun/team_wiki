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
    self.tags = names.map { |name| Tag.find_or_create_by!(name: name) }
  end
end
