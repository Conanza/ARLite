# ActiveRecordLite

## Description

In this test-driven project, I use a little metaprogramming to build a lite version of ActiveRecord to understand how it actually works, how it gets translated into SQL.

## Topics

* Ruby
* SQL
* ActiveRecord
* Metaprogramming
* Macros

## Phase 0: `my_attr_accessor`

What happens if Ruby didn't provide the convenient `attr_accessor` for us?

I write a `::my_attr_accessor` macro, which defines setter/getter methods. I do this by using `define_method`. The methods I define use the `instance_variable_get` and `instance_variable_set` methods
described [here][ivar-get].

[ivar-get]: http://ruby-doc.org/core-2.0.0/Object.html#method-i-instance_variable_get

## Phase I: `SQLObject`: Overview

I write a class, `SQLObject` (i.e. a Rails model), that interacts with the database using raw SQL. Just like the real `ActiveRecord::Base`, it has the following methods:

* `::all`: returns an array of all the records in the DB
* `::find`: looks up a single record by primary key
* `#insert`: inserts a new row into the table to represent the
  `SQLObject`.
* `#update`: updates the row with the `id` of this `SQLObject`
* `#save`: convenience method that either calls `insert`/`update`
  depending on whether or not the `SQLObject` already exists in the table.

### Phase Ia: `::table_name` and `::table_name=`

Getter/setter methods for the class to figure out which table the records should be fetched from, inserted into, etc. Stores this in a class ivar.

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

### Phase Ib: Getters and Setters

When we define a model class `Cat < SQLObject`, it should automatically get setter and getter methods for each of the
columns in its table.

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

`#attributes` instance method initializes `@attributes` to an empty hash and stores any new values added to it.


## Phase Id: `#initialize`

Write an `#initialize` method for `SQLObject`. It should take in a
single `params` hash. We want:

```ruby
cat = Cat.new(name: "Gizmo", owner_id: 123)
cat.name #=> "Gizmo"
cat.owner_id #=> 123
```

Your `#initialize` method should iterate through each of the `attr_name,
value` pairs. For each `attr_name`, it should first convert the name to
a symbol, and then check whether the `attr_name` is among the `columns`.
If it is not, raise an error:

    unknown attribute '#{attr_name}'

Set the attribute by calling the setter method. Use `#send`; avoid
using `@attributes` or `#attributes` inside `#initialize`.

**Hint**: we need to call `::columns` on a class object, not the
instance. For example, we can call `Dog::columns` but not
`dog.columns`.

Note that `dog.class == Dog`. How can we use the `Object#class` method
to access the `::columns` **class method** from inside the
`#initialize` **instance method**?

Run the specs, Luke!

## Phase Ie: `::all`, `::parse_all`

We now want to write a method `::all` that will fetch all the records
from the database. The first thing to do is to try to generate the
necessary SQL query to issue. Generate SQL and print it out so you can
view and verify it. Use the heredoc syntax to define your query.

Example:

```ruby
class Cat < SQLObject
  finalize!
end

Cat.all
# SELECT
#   cats.*
# FROM
#   cats

class Human < SQLObject
  self.table_name = "humans"

  finalize!
end

Human.all
# SELECT
#   humans.*
# FROM
#   humans
```

Notice that the SQL is formulaic except for the table name, which we
need to insert. Use ordinary Ruby string interpolation (`#{whatevs}`) for
this; SQL will only let you use `?` to interpolate **values**, not
table or column names.

Once we've got our query looking good, it's time to execute it. Use
the provided `DBConnection` class. You can use
`DBConnection.execute(<<-SQL, arg1, arg2, ...)` in the usual manner.

Calling `DBConnection` will return an array of raw `Hash` objects
where the keys are column names and the values are column values. We
want to turn these into Ruby objects:

```ruby
class Human < SQLObject
  self.table_name = "humans"

  finalize!
end

Human.all
=> [#<Human:0x007fa409ceee38
  @attributes={:id=>1, :fname=>"Devon", :lname=>"Watts", :house_id=>1}>,
 #<Human:0x007fa409cee988
  @attributes={:id=>2, :fname=>"Matt", :lname=>"Rubens", :house_id=>1}>,
 #<Human:0x007fa409cee528
  @attributes={:id=>3, :fname=>"Ned", :lname=>"Ruggeri", :house_id=>2}>]
```

To turn each of the `Hash`es into `Human`s, write a
`SQLObject::parse_all` method. Iterate through the results, using
`new` to create a new instance for each.

`new` what? `SQLObject.new`? That's not right, we want `Human.all` to
return `Human` objects, and `Cat.all` to return `Cat`
objects. **Hint**: inside the `::parse_all` class method, what is
`self`?

Run the `::parse_all` and `::all` specs! Then carry on!

## Phase If: `::find`

Write a `SQLObject::find(id)` method to return a single object with
the given id. You could write `::find` using `::all` and `Array#find`
like so:

```ruby
class SQLObject
  def self.find(id)
    self.all.find { |obj| obj.id == id }
  end
end
```

That would be inefficient: we'd fetch all the records from the DB.
Instead, write a new SQL query that will fetch at most one record.

Yo dawg, I heard you like specs, so I spent a lot of time writing
them. Please run them again. :-)

## Phase Ih: `#insert`

Write a `SQLObject#insert` instance method. It should build and
execute a SQL query like this:

```sql
INSERT INTO
  table_name (col1, col2, col3)
VALUES
  (?, ?, ?)
```

To simplify building this query, I made two local variables:

* `col_names`: I took the array of `::columns` of the class and
  joined it with commas.
* `question_marks`: I built an array of question marks (`["?"] * n`)
  and joined it with commas. What determines the number of question marks?

Lastly, when you call `DBConnection.execute`, you'll need to pass in
the values of the columns. Two hints:

* I wrote a `SQLObject#attribute_values` method that returns an array
  of the values for each attribute. I did this by calling `Array#map`
  on `SQLObject::columns`, calling `send` on the instance to get
  the value.
* Once you have the `#attribute_values` method working, I passed this
  into `DBConnection.execute` using the splat operator.

When the DB inserts the record, it will assign the record an ID.
After the `INSERT` query is run, we want to update our `SQLObject`
instance with the assigned ID. Check out the `DBConnection` file for a
helpful method.

Again with the specs please.

## Phase Ii: `#update`

Next we'll write a `SQLObject#update` method to update a record's
attributes. Here's a reminder of what the resulting SQL should look
like:

```sql
UPDATE
  table_name
SET
  col1 = ?, col2 = ?, col3 = ?
WHERE
  id = ?
```

This is very similar to the `#insert` method. To produce the
"SET line", I mapped `::columns` to `#{attr_name} = ?` and joined with
commas.

I again used the `#attribute_values` trick. I additionally passed in
the `id` of the object (for the last `?` in the `WHERE` clause).

Every day I'm testing.

## Phase Ij: `#save`

Finally, write an instance method `SQLObject#save`. This should call
`#insert` or `#update` depending on whether `id.nil?`. It is not
intended that the user call `#insert` or `#update` directly (leave
them public so the specs can call them :-)).

You did it! Good work!

## Phase II: `Searchable`

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

## Phase III+: Associations

[Page on over to the association phases!][ar-part-two]

[ar-part-two]: ./w3d5-build-your-own-ar-p2.md
