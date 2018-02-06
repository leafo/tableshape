
# tableshape

[![Build Status](https://travis-ci.org/leafo/tableshape.svg?branch=master)](https://travis-ci.org/leafo/tableshape)

A Lua library for verifying the shape (schema, structure, etc.) of a table, and
transforming it if necessary. The type checking syntax is inspired by the [PropTypes
module of React](https://facebook.github.io/react/docs/reusable-components.html#prop-validation).

Complex types value transformations can be expressed using an operator
overloading syntax similar to [LPeg](http://www.inf.puc-rio.br/~roberto/lpeg/).

### Install

```bash
$ luarocks install tableshape
```

### Quick usage

```lua
local types = require("tableshape").types

-- define the shape of our player object
local player_shape = types.shape{
  class = types.one_of{"player", "enemy"},
  name = types.string,
  position = types.shape{
    x = types.number,
    y = types.number,
  },
  inventory = types.array_of(types.shape{
    name = types.string,
    id = types.integer
  }):is_optional()
}



-- create a valid object to test the shape with
local player = {
  class = "player",
  name = "Lee",
  position = {
    x = 2.8,
    y = 8.5
  },
}

-- verify that it matches the shape
assert(player_shape:check_value(player))

-- let's break the shape to see the error message:
player.position.x = "heck"
assert(player_shape:check_value(player))

-- error: field `position`: field `x`: got type `string`, expected `number`
```

#### Transforming

A malformed table can be repaired be repaired to the expected type by using the
transform operator and method. The input value is cloned and modified before being returned.


```lua
local types = require("tableshape").types

-- a type checker that will coerce the value into a number or return 0
local number = types.number + types.string / tonumber + types.any / 0

number:transform(5) --> 5
number:transform("500") --> 500
number:transform("hi") --> 0
number:transform({}) --> 0

```

```lua
-- a compound type checker that can fill in missing values
local player_shape = types.shape({
  name = types.string + types.any / "unknown"

  -- here we reference our transforming type from above
  position = types.shape({
    x = number,
    y = number
  })
})

local bad_player = {
  position = {
    x = "234",
    y = false
  }
}

local fixed_player = player_shape:transform(bad_player)

-- fixed_player --> {
--   name = "unknown",
--   position = {
--     x = 234,
--     y = 0
--   }
-- }
```

## Tutorial

To load the library `require` it. The most important part of the library is the
`types` table, which will give you acess to all the type checkers

```lua
local types = require("tableshape").types
```

You can use the types table to check the types of simple values, not just
tables. The `check_value` method on any type object will test a value to see if
it matches the shape or type. It returns `true` on a match, or `nil` and the
error message if it fails.

```lua
assert(types.string:check_value("hello!")) -- success
assert(types.string:check_value(777)) -- an error: got type `number`, expected `string`
```

You can see the full list of the available types below in the reference.

The real power of `tableshape` comes from the ability to describe complex types
by nesting the type checkers.

Here we test for an array of numbers by using `array_of`:

```lua
local numbers_shape = types.array_of(types.number)

assert(numbers_shape:check_value({1,2,3}))

-- error: item 2 in array does not match: got type `string`, expected `number`
assert(numbers_shape:check_value({1,"oops",3}))
```

> **Note:** The type checking is strict, a string that looks like a number,
> `"123"`, is not a number and will trigger an error!

The structure of a hashtable can be tested with `types.shape`. It takes a hash
table where the key is the field to check, and the value is the type checker:

```lua
local object_shape = types.shape{
  id = types.number,
  name = types.string:is_optional(),
}

-- success
assert(object_shape:check_value({
  id = 1234,
  name = "hello world"
}))

-- sucess, optional field is not there
assert(object_shape:check_value({
  id = 1235,
}))


-- error: field `id`: got type `nil`, expected `number`
assert(object_shape:check_value({
  name = 424,
}))
```

The `is_optional` method can be called on a type checker to make that type also
accept `nil` as a value.

If multiple fields fail the type check, only the first one is reported as the second return value.

You can also use a literal value to match it directly:

```lua
local object_shape = types.shape{
  name = "Cowcat"
}

-- error: field `name` expected `Cowcat`
assert(object_shape:check_value({
  name = "Cowdog"
}))
```

The `one_of` type constructor lets you specify a list of types, and will
succeed if one of them matches.


```lua
local func_or_bool = types.one_of{types.func, types.boolean}

assert(func_or_bool:check_value(function() end))

-- error: value `2345` did not match one of: type `function`, type `boolean`
assert(func_or_bool:check_value(2345))
```

It can also be used with literal values as well:

```lua
local limbs = types.one_of{"foot", "arm"}

assert(limbs:check_value("foot")) -- success
assert(limbs:check_value("arm")) -- success

-- error: value `baseball` did not match one of: `foot`, `arm`
assert(limbs:check_value("baseball"))
```

The `pattern` type can be used to test a string with a Lua pattern

```lua
local no_spaces = types.pattern "^[^%s]*$"

assert(no_spaces:check_value("hello!"))

-- error: doesn't match pattern `^[^%s]*$`
assert(no_spaces:check_value("oh no!"))
```

### Type operators

Type checker objects have the operators `*`, `+`, and `/` overloaded to provide
ways to compose into types into more complex ones.

* `*` — The **and** operator, both operands must match.
* `+` — The **first of** operator, the operands are checked against the value from left to right
* `/` — The **transform** operator, when using the `transform` method, the value will be convered by what's to the right of the operator

#### The 'and' operator

The **and** operator checks if a value matches multiple types. Types are
checked from left to right, and type checking will abort on the first failed check.

```lua
local s = types.pattern("^hello") * types.pattern("world$")

s("hello 777 world")   --> true
s("good work")         --> nil, "doesn't match pattern `^hello`"
s("hello, umm worldz") --> nil, "doesn't match pattern `world$`"
```

#### The 'first of' operator

The **first of** operator checks if a value matches one of many types. Types
are checked from left to right, and type checking will succeed on the first
matched type.

Once a type has been matched no additional types are checked. If you use a
greedy type first, (like `types.any`) then it will check any additional ones.
This is important to realize if your subsequent types have any side effects
like transformations or tags.


```lua
local s = types.number + types.string

s(44)                  --> true
s("hello, umm worldz") --> nil, "no matching option (got type `boolean`, expected `number`; got type `boolean`, expected `string`)"
```

### The 'transform' operator

In type matching mode, the transform operator has no effect. When using the
`transform` method, however, the value will be modified by a callback or to be
a fixed value.

The following syntax is used: `type / transform_callback --> transformable type`

```lua
local t = types.string + types.any / "unknown"
```

The proceeding type can be read as: "Match a string typed value, or for any
other type, transform it into the string 'unknown'".

```lua
t:transform("hello") --> "hello"
t:transform(5)       --> "unknown"
```

Because this type checker uses `types.any`, it will pass for whatever value is
handed to it. A transforming type check can fail as well.

```lua
local n = types.number + types.string / tonumber

n:transform("5") --> 5
n:t({})          --> nil, "no matching option (got type `table`, expected `number`; got type `table`, expected `string`)"
```

The transform callback can either be a function, or a literal value. If a
function is used, then the function is called with the current value being
transformed, and the result of the transformation should be returned. If a
literal value is used, then the transformations always turns the value into the
specified value.

A transform function is not a predicate, and can't cause the type checking to
fail. Returning `nil` is valid and will change the value to `nil`. If you wish
to fail based on a function you can use the `custom` type or chain another type
checker after the transformation:


```lua
-- this will fail unless `tonumber` returns a number
local t = (types.string / tonumber) * types.number
t:transform("nothing") --> nil, "got type `nil`, expected `number`"
```

A common pattern for repairing objects involves testing for the types you know
how to fix followed by ` + types.any`, followed by a type check of the final
type you want:

Here we attempt to repair a value to the expected format for a x,y coordinate:


```lua
local types = require("tableshape").types

local str_to_coord = types.string / function(str)
  local x,y = str:match("(%d+)[^%d]+(%d+)")
  if nox x then return end
  return {
    x = tonumber(x),
    y = tonumber(y)
  }
end

local array_to_coord = types.shape{types.number, types.number} / function(a)
  return {
    x = a[1],
    y = a[2]
  }
end

local cord = (str_to_coord + array_to_coord + types.any) * types.shape {
  x = types.number,
  y = types.number
}

cord:transform("100,200")        --> { x = 100, y = 200}
cord:transform({5, 23})          --> { x = 5, y = 23}
cord:transform({ x = 9, y = 10}) --> { x = 9, y = 10}
```

### Tags

Tags can be used to extract specified values from a type as it's checked.

If tags are used, then a table of tags is returned as the second return value
from a successful type match.

```lua
loca t = types.shape {
  a = types.number:tag("x"),
  b = types.number:tag("y"),
} + types.shape {
  types.number:tag("x"),
  types.number:tag("y"),
}

t({1,2})          --> true, { x =  1, y = 2}
t({a = 3, b = 9}) --> true, { x = 3, y = 9}
```

### Transforming

When calling a type object with the transform method you can modify transform
the input with callbacks until it matches the types you specify. This is done
with a combination of type operators, including the `transform` operator.

For example, we can take pattern type checker for URLs that fixes the input:

```lua
local url_shape = types.pattern("^https?://") + types.string / function(val)
  return "http://" .. val
end
```

> If you pass a mutable object, like a table, then any transformations will be
> done on a copies of the data. The original object will not be modified. A new
> copy is always returned, even if no transformations take place.

```lua
url_shape:transform("https://itch.io") --> https://itch.io
url_shape:transform("leafo.net")       --> http://leafo.net
url_shape:transform({})                --> nil, "no matching option (expected string for value; got type `table`)"
```

We can compose transformable type checkers. Now that we know how to fix a URL,
we can fix an array of URLS:


```lua
local urls_array = types.array_of(url_shape)

local fixed_urls = urls_array:transform({
  "https://itch.io",
  "leafo.net",
  {}
  "www.streak.club",
})
```

The `transform` method of the `array_of` type will transform each value of the
array. A special property of the `array_of` transform is to exclude any values
that get turned into `nil` in the final output. You can use this to filter out
any bad data without having holes in your array. (You can override this with
the `keep_nils` option.

## Reference

```lua
local types = require("tableshape").types
```

### Type constructors

Type constructors build a type checker configured by the parameters you pass.
Here are all the available ones, full documentation is below.

* `types.shape` - checks the shape of a table
* `types.one_of` - checks if value matches one of the types provided
* `types.pattern` - checks if Lua pattern matches value
* `types.array_of` - checks if value is array of type
* `types.map_of` - checks if value is table that matches key and value types
* `types.literal` - checks if value matches the provided value with `==`
* `types.custom` - lets you provide a function to check the type

#### `types.shape(table_dec)`

Returns a type checker tests for a table where every key in `table_dec` has a
type matching the associated value. The associated value can also be a literal
value.

```lua
local t = types.shape{
  id = types.number,
  name = types.string
}
```

#### `types.array_of(item_type, options={})`

Returns a type checker that tests if the value is an array where each item
matches the provided type.

```lua
local t = types.array_of(types.shape{
  id = types.number
})
```

The following options are supported:

* `keep_nils` &mdash; By default, if a value is transformed into a nil then it won't be kept in the output array. If you need to keep these holes then set this option to `true`

#### `types.map_of(key_type, value_type)`

Returns a type checker that tests for a table where every key and value matches
the respective type checkers provided as arguments.

```lua
local t = types.map_of(types.string, types.any)
```

#### `types.one_of({type1, type2, ...})`

Returns a type checker that tests if the value matches one of the provided
types. A literal value can also be passed as a type.

```lua
local t = types.one_of{"none", types.number}
```

#### `types.pattern(lua_pattern)`

Returns a type checker that tests if a string matches the provided Lua pattern

```lua
local t = types.pattern("^#[a-fA-F%d]+$")
```

#### `types.literal(value)`

Returns a type checker that checks if value is equal to the one provided. When
using shape this is normally unnecessary since non-type checker values will be
checked literally with `==`. This lets you attach a repair function to a
literal check.

```lua
local t = types.literal "hello world"
assert(t("hello world") == true)
assert(t("jello world") == false)
```

#### `types.custom(fn)`

Returns a type checker that calls the function provided to verify the value.
The function will receive the value being tested as the first argument, and the
type checker as the second.

The function should return true if the value passes, or `nil` and an error
message if it fails.

```lua
local is_even = types.custom(function(val)
  if type(val) == "number" then
    if val % 2 == 0 then
      return true
    else
      return nil, "number is not even"
    end
  else
    return nil, "expected number"
  end
end)
```

#### types.equivalent(val)

Returns a type checker that will do a deep compare between val and the input.

```lua
local t = types.equivalent {
  color = {255,100,128},
  name = "leaf"
}

-- although we're testing a different instance of the table, the structure is
-- the same so it passes
t {
  name = "leaf"
  color = {255,100,128},
} --> true

```

### Built in types

Built in types can be used directly without being constructed.

* `types.string` - checks for `type(val) == "string"`
* `types.number` - checks for `type(val) == "number"`
* `types.func` - checks for `type(val) == "function"`
* `types.boolean` - checks for `type(val) == "boolean"`
* `types.userdata` - checks for `type(val) == "userdata"`
* `types.table` - checks for `type(val) == "table"`
* `types.nil` - checks for `type(val) == "nil"`
* `types.array` - checks for table of numerically increasing indexes
* `types.integer` - checks for a number with no decimal component

Additionally there's the special *any* type:

* `types.any` - succeeds no matter what the type

### Type methods

Every type checker has the follow methods:

#### `type:check_value(value)`

Tests `value` against the type checker. Returns `true` if the value passes the
check. Returns `nil` and an error message as a string if there is a mismatch.
The error message will identify where the mismatch happened as best it can.

`check_value` will abort on the first error found, and only that error message is returned.

Can also be invoked by calling the type checker object, the `__call` metamethod
is overidden to call this method.

#### `type:transform(value)`

Will make a deep copy of the value, checking the type and performing any
transformations if necessary. You can use the *transform operator* (`/`) to specify
how values are transformed.

```lua
local t = types.number + types.string / tonumber

t:transform(10) --> 10
t:transform("15") --> 15
```

If any tags are used, a tabled of tagged values is returned as the second
argument.

#### `type:repair(value)`

An alias for `type:transform(value)`

#### `type:is_optional()`

Returns a new type checker that matches the same type, or `nil`.

#### `shape_type:is_open()`

> This method is deprecated, use the `open = true` constructor option on shapes instead

This method is only available on a type checker generated by `types.shape`.

Returns a new shape type checker that won't fail if there are extra fields not
specified.

#### `type:on_repair(func)`

An alias for the transform pattern:

```lua
type + types.any / func * type
```

In English, this will let a value that matches `type` pass through, otherwise
for anything else call `func(value)` and let the return value pass through if
it matches `type`, otherwise fail.

## Changelog

**Next** - 2.0.0

* Add overloaded operators to compose types
* Add transformation interface
* Add support for tagging
* Add `state` parameter that's passed through type checks (internal use only right now)
* Replace repair interface with simple transform

**Feb 10 2016** - 1.2.1

* Fix bug where literal fields with no dot operator could not be checked
* Better failure message when field doesn't match literal value
* Add `types.nil`

**Feb 04 2016** - 1.2.0

* Add the repair interface

**Jan 25 2016** - 1.1.0

* Add `types.map_of`
* Add `types.any`

**Jan 24 2016**

* Initial release

## License (MIT)

Copyright (C) 2016 by Leaf Corcoran

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

