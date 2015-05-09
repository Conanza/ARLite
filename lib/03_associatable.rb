require_relative '02_searchable'
require 'active_support/inflector'

# Phase IIIa
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
  # Phase IIIb
  def belongs_to(name, options = {})
    opts = BelongsToOptions.new(name, options)

    define_method(name.to_sym) do 
      object = opts.model_class.where(id: self.send(opts.foreign_key))

      object.first
    end
  end

  def has_many(name, options = {})
    opts = HasManyOptions.new(name, self.name, options)

    define_method(name.to_sym) do 
      opts.model_class.where(opts.foreign_key => self.send(opts.primary_key))
    end
  end

  def assoc_options
    # Wait to implement this in Phase IVa. Modify `belongs_to`, too.
  end
end

class SQLObject
  extend Associatable
end
