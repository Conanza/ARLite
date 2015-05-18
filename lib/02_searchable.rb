require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    where_line = params.keys
      .map { |attr| "#{attr} = ?" }
      .join(" AND ")

    objects = DBConnection.execute(<<-SQL, *params.values)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        #{where_line};
    SQL

    parse_all(objects)
  end
end

class SQLObject
  extend Searchable
end
