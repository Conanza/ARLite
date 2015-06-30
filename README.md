# ActiveRecordLite

## Description

In this test-driven project, I use a little metaprogramming to build a lite version of ActiveRecord to understand how it actually works, how it gets translated into SQL.

## Topics

* Ruby
* SQL
* ActiveRecord
* Metaprogramming
* Macros

## Walkthrough

### Phase 0: `my_attr_accessor`

What happens if Ruby didn't provide the convenient `attr_accessor` for us?

I write a `::my_attr_accessor` macro, which defines setter/getter methods. I do this by using `define_method`. The methods I define use the `instance_variable_get` and `instance_variable_set` methods
described [here][ivar-get].

[ivar-get]: http://ruby-doc.org/core-2.0.0/Object.html#method-i-instance_variable_get

### Phase I: `SQLObject`: Overview

I write a class, `SQLObject` (i.e. a Rails model), that interacts with the database using raw SQL. Just like the real `ActiveRecord::Base`, it has the following methods:

* `::all`: returns an array of all the records in the DB
* `::find`: looks up a single record by primary key
* `#insert`: inserts a new row into the table to represent the
  `SQLObject`.
* `#update`: updates the row with the `id` of this `SQLObject`
* `#save`: convenience method that either calls `insert`/`update`
  depending on whether or not the `SQLObject` already exists in the table.

#### Phase Ia: `::table_name` and `::table_name=`

Helper getter/setter methods for the class to figure out which **table** the records should be fetched from, inserted into, etc. Stores this in a class ivar.

Example:

```ruby
class Human < SQLObject
  self.table_name = "humans"
end

Human.table_name # => "humans"
```

In the absence of an explicitly set table, `::table_name` by default converts the class name to snake\_case and pluralizes:

```ruby
class BigDog < SQLObject
end

BigDog.table_name # => "big_dogs"
```

This is done using the `String#tableize` method that the ActiveSupport inflector library provides.

#### Phase Ib: Attribute Getters and Setters

When we define a model class `Cat < SQLObject`, it should automatically get setter and getter methods for each of the columns in its table (i.e. its attributes).

To accomplish this:
`::columns` returns an array with the names of the table's columns as symbols.

`::finalize!` (has to be called at the end of a subclass definition) calls `::columns` and iterates through the columns, using `define_method` to define a getter and setter instance method for each.

Setter methods store all the record data in an attributes hash. Example:

```ruby
cat = Cat.new
cat.attributes #=> {}
cat.name = "Gizmo"
cat.attributes #=> { name: "Gizmo" }
```

`#attributes` initializes `@attributes` to an empty hash and stores any new values added to it.

#### Phase Ic: `#initialize`

`#initialize` method for `SQLObject` takes in a single `params` hash.

Example:

```ruby
cat = Cat.new(name: "Gizmo", owner_id: 123)
cat.name #=> "Gizmo"
cat.owner_id #=> 123
```

It iterates through each of the `attr_name, value` pairs, and checks whether the `attr_name` is among the `columns`. If not, it raises an error.

Uses `#send` to set the attributes by calling the respective setter method.

#### Phase Id: `::all`, `::parse_all`

`::all` fetches all the records from the database. Breaking it down:

The SQL is formulaic except for the table name, so I just interpolate the value from `::table_name` (SQL only lets us use `?` to interpolate **values**, not
table or column names).

I've been using the `DBConnection` class and `DBConnection.execute(<<-SQL, arg1, arg2, ...)` to execute SQL queries. This returns an array of raw `Hash` objects where the keys are column names and the values are column values.

So I write a `SQLObject::parse_all` method that iterates through these results, using `self.new` (self is the class inside a class method) to instantiate a new Ruby object for each result.

I call `::parse_all` at the end of `::all`.

#### Phase Ie: `::find`

Given an id, `SQLObject::find(id)` returns a single object.

Again, I use `::parse_all` at the end to get the Ruby object.

#### Phase If: `#insert`

`SQLObject#insert` builds and executes a SQL query while taking care to leave out the `id` column. It needs to look like this:

```sql
INSERT INTO
  table_name (col1, col2, col3)
VALUES
  (?, ?, ?)
```

So to build this query there's a few extra steps:

* `col_names`: Joined the array of `::columns` (leaving out `id`) with commas.
* `question_marks`: Joined an array of question marks (`["?"] * n`), where `n` is the number of columns, with commas.

I need to pass in values for the columns when calling `DBConnection.execute`:

* `SQLObject#attribute_values_without_id` returns an array of the values for each attribute, excluding `id`.
* Pass this into `DBConnection.execute` using the splat operator.

Lastly, I update the `SQLObject` instance with the assigned ID using `DBConnection#last_insert_row_id`.

#### Phase Ig: `#update`

`SQLObject#update` updates a record's attributes. Like insert, I build and produce a query that looks like this:

```sql
UPDATE
  table_name
SET
  col1 = ?, col2 = ?, col3 = ?
WHERE
  table_name.id = ?
```

I pass in the attribute values and the `id` of the object to update.

#### Phase Ih: `#save`

Now that I have `#insert` and `#update`, `SQLObject#save` calls one or the other depending if `id.nil?`. 

### Phase II: `Searchable`

Let's write a module named `Searchable` which will add the ability to
search using `::where`. By using `extend`, we can mix in `Searchable`
to our `SQLObject` class, adding all the module methods as class
methods.

So let's write `Searchable#where(params)`. Here's an example:

```ruby
haskell_cats = Cat.where(:name => "Haskell", :color => "calico")
# SELECT
#   *
# FROM
#   cats
# WHERE
#   name = ? AND color = ?
```

I used a local variable `where_line` where I mapped the `keys` of the
`params` to `"#{key} = ?"` and joined with `AND`.

To fill in the question marks, I used the `values` of the `params`
object.

### Phase III+: Associations

[Page on over to the association phases!][ar-part-two]

[ar-part-two]: ./w3d5-build-your-own-ar-p2.md
