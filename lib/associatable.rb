class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  # Returns associated object's class
  def model_class
    class_name.constantize
  end

  # Returns associated object's table name
  def table_name
    model_class.table_name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    defaults = {
      foreign_key: "#{name.to_s.singularize}_id".to_sym,
      class_name: name.to_s.camelcase,
      primary_key: :id
    }.merge(options)

    @foreign_key, @class_name, @primary_key =
      defaults.values_at(:foreign_key, :class_name, :primary_key)
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    defaults = {
      foreign_key: "#{self_class_name.downcase}_id".to_sym,
      class_name: name.to_s.singularize.camelcase,
      primary_key: :id
    }.merge(options)

    @foreign_key, @class_name, @primary_key =
      defaults.values_at(:foreign_key, :class_name, :primary_key)
  end
end

module Associatable
  def assoc_options
    @assoc_options ||= {}
  end

  def belongs_to(name, options = {})
    assoc_options[name] = BelongsToOptions.new(name, options)

    define_method(name.to_sym) do
      object = self.class.assoc_options[name]
        .model_class
        .where(id: self.send(self.class.assoc_options[name].foreign_key))

      object.first
    end
  end

  def has_many(name, options = {})
    opts = HasManyOptions.new(name, self.name, options)

    define_method(name.to_sym) do
      opts.model_class.where(opts.foreign_key => self.send(opts.primary_key))
    end
  end

  def has_one_through(name, through_name, source_name)
    define_method(name.to_sym) do
      through_opts = self.class.assoc_options[through_name]
      source_opts = through_opts.model_class.assoc_options[source_name]
      through_table = through_opts.table_name
      source_table = source_opts.table_name

      objects = DBConnection.execute(<<-SQL, attributes[through_opts.foreign_key])
        SELECT
          #{source_table}.*
        FROM
          #{source_table}
        JOIN
          #{through_table}
        ON
          (#{through_table}.#{source_opts.foreign_key} =
            #{source_table}.#{source_opts.primary_key})
        WHERE
          (#{through_table}.#{through_opts.primary_key} = ?);
      SQL

      source_opts.model_class.parse_all(objects).first
    end
  end

  def has_many_through(name, through_name, source_name)
    define_method(name.to_sym) do
      through_opts = self.class.assoc_options[through_name]
      source_opts = through_opts.model_class.assoc_options[source_name]
      through_table = through_opts.table_name
      source_table = source_opts.table_name

      objects = DBConnection.execute(<<-SQL, attributes[through_opts.foreign_key])
        SELECT
          #{source_table}.*
        FROM
          #{source_table}
        JOIN
          #{through_table}
        ON
          (#{through_table}.#{source_opts.foreign_key} =
            #{source_table}.#{source_opts.primary_key})
        WHERE
          (#{through_table}.#{through_opts.primary_key} = ?);
      SQL

      source_opts.model_class.parse_all(objects)
    end
  end
end
