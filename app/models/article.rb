class Article < ApplicationRecord
  include FuzzyDateAttributable
  include Taggable

  KINDS = { "work" => "作品", "person" => "人物", "event" => "出来事" }.freeze
  STATUSES = { "stub" => "スタブ", "writing" => "執筆中", "done" => "完成" }.freeze

  belongs_to :created_by, class_name: "User"
  belongs_to :current_revision, class_name: "Revision", optional: true
  has_many :revisions, dependent: :destroy
  has_many :outgoing_links, class_name: "Link", foreign_key: :source_article_id, dependent: :destroy
  has_many :inbound_links, class_name: "Link", foreign_key: :target_article_id, dependent: :nullify
  has_many :citations, dependent: :destroy
  has_many :cited_materials, -> { distinct }, through: :citations, source: :material
  has_many :comments, as: :commentable, dependent: :destroy
  # 削除後もタイムラインは subject_label のスナップショットで表示する（参照だけ外す）。
  has_many :activities, as: :subject, dependent: :nullify

  validates :title, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  # フォームの「未分類」(include_blank) は "" を送る。空文字は nil 扱いにして allow_nil を効かせる。
  normalizes :kind, with: ->(v) { v.presence }
  validates :kind, inclusion: { in: KINDS.keys }, allow_nil: true
  validates :status, inclusion: { in: STATUSES.keys }

  fuzzy_date_attribute :starts_at, accessor: :start
  fuzzy_date_attribute :ends_at, accessor: :end

  before_validation :assign_slug, on: :create

  scope :chronicled, -> { where.not(starts_at: nil).order(:starts_at) }

  validates :starts_precision, inclusion: { in: FuzzyDate::PRECISIONS }, allow_nil: true
  validates :ends_precision, inclusion: { in: FuzzyDate::PRECISIONS }, allow_nil: true

  validate :date_range_consistent

  def to_param = slug

  def kind_label = kind ? KINDS[kind] : "未分類"
  def status_label = STATUSES[status]

  # リビジョンの author を初参加順（最初に貢献した順）で重複除去して返す。
  def contributors
    ids = revisions.order(:created_at).pluck(:author_id).uniq
    by_id = User.where(id: ids).with_attached_avatar.index_by(&:id)
    ids.map { |id| by_id[id] }
  end

  # 本文を改訂する。自身の属性変更を保存し、本文が前版と異なる時だけ版を追記して
  # current_revision を差し替え、リンク/引用/逆リンクを同期する（同期はタイトル変更等に
  # 効くので本文不変でも通す）。current_revision を返す。activity はコントローラの責務。
  def revise!(body:, author:, edit_summary: nil)
    transaction do
      save!
      if current_revision&.body != body
        revision = revisions.create!(body: body, author: author, edit_summary: edit_summary)
        update!(current_revision: revision)
      end
      sync_outgoing_links(body)
      sync_citations(body)
      backfill_inbound_links
      current_revision
    end
  end

  # 過去版の本文へ復元する（現在のタグを引き継ぐ）。activity はコントローラの責務。
  # tag_names= は CSV 文字列を期待する（Taggable#sync_tags）ので join してから渡す。
  def restore_revision!(revision, author:)
    self.tag_names = tags.pluck(:name).join(", ")
    revise!(body: revision.body, author: author, edit_summary: "リビジョン##{revision.id} を復元")
  end

  # 新規作成＋初版を作る。activity はコントローラ/呼び出し側の責務。
  def self.create_with_revision!(attributes, body:, author:, edit_summary: nil)
    article = new(attributes)
    article.revise!(body: body, author: author, edit_summary: edit_summary)
    article
  end

  private

  # 本文の [[タイトル]] を outgoing_links に張り直す（未解決は target_article_id=null で残す）。
  def sync_outgoing_links(body)
    titles = WikiLinkExtractor.call(body)
    outgoing_links.delete_all
    by_title = Article.where(title: titles).index_by(&:title)
    titles.each { |t| outgoing_links.create!(target_title: t, target_article_id: by_title[t]&.id) }
  end

  # 本文の [[ref:handle]] を citations に張り直す（handle=資料slug を解決、未解決は material=nil）。
  def sync_citations(body)
    handles = RefExtractor.call(body)
    citations.delete_all
    by_slug = Material.where(slug: handles).index_by(&:slug)
    handles.each { |h| citations.create!(material_handle: h, material: by_slug[h]) }
  end

  # 自分のタイトルを指す未解決リンクを埋め戻す（冪等）。
  def backfill_inbound_links
    Link.where(target_title: title, target_article_id: nil)
        .where.not(source_article_id: id)
        .update_all(target_article_id: id)
  end

  def date_range_consistent
    errors.add(:starts_at, "が必要です") if ends_at.present? && starts_at.blank?
    if starts_at.present? && ends_at.present? && ends_at < starts_at
      errors.add(:ends_at, "は開始以降にしてください")
    end
  end

  def assign_slug
    self.slug ||= Slug.unique_token { |c| Article.exists?(slug: c) }
  end
end
