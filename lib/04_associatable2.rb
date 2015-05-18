require_relative '03_associatable'

# Phase IV
module Associatable
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
