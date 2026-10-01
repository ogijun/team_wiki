class ExpandFuzzyTimestamps < ActiveRecord::Migration[8.1]
  SOURCES = {
    articles: [ [ :starts_at, :starts_precision, :starts ], [ :ends_at, :ends_precision, :ends ] ],
    materials: [ [ :published_at, :published_precision, :published ] ],
    publications: [ [ :released_at, :released_precision, :released ] ]
  }.freeze
  FORMATS = { "year" => "%Y", "month" => "%Y-%m", "day" => "%Y-%m-%d", "time" => "%Y-%m-%dT%H:%M" }.freeze

  class MigrationRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  def up
    add_column :articles, :starts, :string
    add_column :articles, :ends, :string
    add_column :materials, :published, :string
    add_column :publications, :released, :string
    add_index :articles, :starts
    add_index :materials, :published
    add_index :publications, :released

    SOURCES.each { |table, columns| convert_table(table, columns) }
  end

  def down
    SOURCES.each { |table, columns| restore_table(table, columns) }
    remove_index :publications, :released
    remove_index :materials, :published
    remove_index :articles, :starts
    remove_column :publications, :released
    remove_column :materials, :published
    remove_column :articles, :ends
    remove_column :articles, :starts
  end

  def timestamp_from(time, precision)
    raise "unknown precision: #{precision.inspect}" unless FORMATS.key?(precision)

    local = time.in_time_zone
    return format("%04d", local.year) if precision == "year"

    local.strftime(FORMATS.fetch(precision))
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

  def convert_table(table, columns)
    model = record_class(table)
    columns.each do |at, precision, target|
      incomplete = model.where(at => nil).where.not(precision => nil).or(model.where.not(at => nil).where(precision => nil))
      raise "#{table}.#{at}/#{precision} is incomplete" if incomplete.exists?

      model.where.not(at => nil).find_each do |row|
        row.update_columns(target => timestamp_from(row.public_send(at), row.public_send(precision)))
      end
      validate_conversion!(model, at, precision, target)
    end
  end

  def validate_conversion!(model, at, precision, target)
    raise "#{model.table_name}.#{target} count mismatch" unless model.where.not(at => nil).count == model.where.not(target => nil).count

    model.where.not(target => nil).find_each do |row|
      value = row.public_send(target)
      expected = row.public_send(precision) == "time" ? :minute : row.public_send(precision).to_sym
      raise "invalid #{model.table_name}.#{target}: #{value.inspect}" unless FuzzyTimestamp.valid?(value)
      raise "precision mismatch #{model.table_name}.#{target}: #{value.inspect}" unless FuzzyTimestamp.precision(value) == expected
    end
  end

  def restore_table(table, columns)
    model = record_class(table)
    columns.each do |at, precision, source|
      model.where(source => nil).update_all(at => nil, precision => nil)
      model.where.not(source => nil).find_each do |row|
        time, old_precision = legacy_from(row.public_send(source))
        row.update_columns(at => time, precision => old_precision)
      end
    end
  end
end
