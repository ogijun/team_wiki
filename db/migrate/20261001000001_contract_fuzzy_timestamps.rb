class ContractFuzzyTimestamps < ActiveRecord::Migration[8.1]
  SOURCES = {
    articles: [ [ :starts_at, :starts_precision, :starts ], [ :ends_at, :ends_precision, :ends ] ],
    materials: [ [ :published_at, :published_precision, :published ] ],
    publications: [ [ :released_at, :released_precision, :released ] ]
  }.freeze

  class MigrationRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  def up
    remove_index :articles, name: :index_articles_on_starts_at
    remove_index :materials, name: :index_materials_on_published_at
    remove_index :publications, name: :index_publications_on_released_at

    remove_columns :articles, :starts_at, :starts_precision, :ends_at, :ends_precision
    remove_columns :materials, :published_at, :published_precision
    remove_columns :publications, :released_at, :released_precision
  end

  def down
    add_column :articles, :starts_at, :datetime
    add_column :articles, :starts_precision, :string
    add_column :articles, :ends_at, :datetime
    add_column :articles, :ends_precision, :string
    add_column :materials, :published_at, :datetime
    add_column :materials, :published_precision, :string
    add_column :publications, :released_at, :datetime
    add_column :publications, :released_precision, :string

    add_index :articles, :starts_at
    add_index :materials, :published_at
    add_index :publications, :released_at

    SOURCES.each { |table, columns| restore_table(table, columns) }
  end

  def legacy_from(value)
    parts = FuzzyTimestamp.parts(value)
    precision = FuzzyTimestamp.precision(value)
    time = Time.zone.local(parts[:year].to_i, (parts[:month] || 1).to_i, (parts[:day] || 1).to_i,
                           (parts[:hour] || 0).to_i, (parts[:minute] || 0).to_i)
    [ time, precision == :minute ? "time" : precision.to_s ]
  end

  private

  def record_class(table)
    Class.new(MigrationRecord) do
      self.table_name = table.to_s
      self.inheritance_column = :_type_disabled
    end.tap(&:reset_column_information)
  end

  def restore_table(table, columns)
    model = record_class(table)
    columns.each do |at, precision, source|
      model.where.not(source => nil).find_each do |row|
        time, old_precision = legacy_from(row.public_send(source))
        row.update_columns(at => time, precision => old_precision)
      end
    end
  end
end
