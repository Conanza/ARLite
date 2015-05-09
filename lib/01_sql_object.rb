require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns

    objects = DBConnection.execute2(<<-SQL)
      SELECT 
        *
      FROM 
        #{table_name};
    SQL

    @columns = objects.first.map(&:to_sym)
  end

  def self.finalize!
    columns.each do |attr|
      define_method(attr) { attributes[attr] }

      define_method("#{attr}=") { |val| attributes[attr] = val }
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.name.tableize
  end

  def self.all
    objects = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM 
        #{table_name};
    SQL

    parse_all(objects)
  end

  def self.parse_all(results)
    results.each_with_object([]) { |attrs, objects| objects << self.new(attrs) }
  end

  def self.find(id)
    object = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM 
        #{table_name}
      WHERE 
        #{table_name}.id = ?;
    SQL

    parse_all(object).first
  end

  def initialize(params = {})
    columns = self.class.columns
    params.each do |attr, val|
      raise "unknown attribute '#{attr}'" unless columns.include?(attr.to_sym)

      self.send("#{attr}=".to_sym, val)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |attr| self.send(attr) }
  end

  def columns_without_id 
    self.class.columns.reject { |attr| attr == :id }
  end

  def attribute_values_without_id
    attributes.values_at(*columns_without_id)
  end

  def insert
    column_names = columns_without_id.join(", ")
    count = column_names.count(",") + 1
    question_marks = (["?"] * count).join(", ")

    DBConnection.execute(<<-SQL, *attribute_values_without_id)
      INSERT INTO 
        #{self.class.table_name} (#{column_names})
      VALUES
        (#{question_marks});
    SQL

    attributes[:id] = DBConnection.last_insert_row_id
  end

  def update
    set_line = columns_without_id
      .map { |attr| "#{attr} = ?" }
      .join(", ")

    DBConnection.execute(<<-SQL, *attribute_values_without_id, attributes[:id])
      UPDATE 
        #{self.class.table_name}
      SET 
        #{set_line}
      WHERE 
        #{self.class.table_name}.id = ?;
    SQL
  end

  def save
    if attributes[:id]
      update
    else
      insert
    end
  end
end
