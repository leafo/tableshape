
# tableshape

[![Build Status](https://travis-ci.org/leafo/tableshape.svg?branch=master)](https://travis-ci.org/leafo/tableshape)

A Lua library for verifying the shape (schema, structure, etc.) of a table, and
repairing it if necessary. The type checking syntax is inspired by the [PropTypes
module of React](https://facebook.github.io/react/docs/reusable-components.html#prop-validation).

### Usage

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

#### Repairing

A malformed table can be repaired by providing the repair callbacks where appropriate:


```lua
local types = require("tableshape").types

-- a type checker that will repair invalid number
local number = types.number:on_repair(function(val)
  return tonumber(val) or 0
end)


-- a compound type checker that can repair multiple fields
local player_shape = types.shape({
  name = types.string:on_repair(function()
    return "unknown"
  end),
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

local fixed_player, did_repair = player_shape:repair(bad_player)

-- did_repair --> true
-- fixed_player --> {
--   name = "unknown",
--   position = {
--     x = 234,
--     y = 0
--   }
-- }
```

### Install

```bash
$ luarocks install tableshape
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

### Repairing

Every type checking object can optionally have a repair callback associated
with it. When using the `repair` method on a type checker, the repair callback
is used to fix the value.

For example, we can take pattern type checker for URLs that fixes the input:

```lua
local url_shape = types.pattern("^https?://"):on_repair(function(val)
  return "http://" .. val
end)
```

If a repair is not required, the same exact value is returned. If a repair is
required, the callback is used to create a new repaired object that is
returned.

> If you pass a mutable object, like a table, then on repair a brand new table
> will be returned. The original object will not be mutated. If a repair is not
> necessary then that same table is returned.

```lua
url_shape:repair("https://itch.io") --> https://itch.io
url_shape:repair("leafo.net") --> http://leafo.net
```

The `repair` has a second return value: it's `true` if the value was repaired,
false otherwise.

Just like the type checkers can be nested and composed, the repair-aware type
checkers can be too. Here we use our `url_shape` type checker combined with
`array_of` to repair an array of URLs.


```lua
local urls_array = types.array_of(url_shape)

local fixed_urls = urls_array:repair({
  "https://itch.io",
  "leafo.net",
  "www.streak.club",
})
```

If the individual components of a compound type checker do not have an
appropriate repair callback, then the repair callback of the compound type
checker is used. The first argument of this callback is the kind of error it
encountered.

For example we can remove extra fields from a table:

```lua
local types = require("tableshape").types

local table_t = types.shape({
  name = types.string,
}):on_repair(function(msg, field, value)
  if msg == "extra_field" then
    return nil -- clear the field by returning nothing
  else
    error("todo: implement repair for: " .. msg)
  end
end)

local res = table_t:repair({
  name = "leaf",
  color = "blue",
})

-- returns:
-- {
--   name = "leaf"
-- }
```

The available repair types for a `types.shape` are `"extra_field"`,
`"field_invalid"`, and `"table_invalid"`.

## Reference

```lua
local types = require("tableshape").types
```

### Compound constructors

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

##### Repair callback

The first argument of the repair callback is a type string which indicates what

* `table_invalid` - Receives `error_message`, `original_value`. The type of the value is not a table, the return value of the callback replaces the value. No further checking is done.
* `field_invalid` - Receives `field_key`, `field_value`, `error_message`, `expected_type`. The return value is used to replace the field in the table. Return `nil` to remove the field.
* `extra_field` - Receives `field_key`, `field_value`. The return value is used to replace the field in the table. Return `nil` to remove the field.

#### `types.array_of(item_type)`

Returns a type checker that tests if the value is an array where each item
matches the provided type.

```lua
local t = types.array_of(types.shape{
  id = types.number
})
```

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
local t = types.array_of{"none", types.number}
```

#### `types.pattern(lua_pattern)`

Returns a type checker that tests if a string matches the provided Lua pattern

```lua
local t = types.pattern("^#[a-fA-F%d]+$")
```

### Types

Basic types:

* `types.string` - checks for `type(val) == "string"`
* `types.number` - checks for `type(val) == "number"`
* `types.func` - checks for `type(val) == "function"`
* `types.boolean` - checks for `type(val) == "boolean"`
* `types.userdata` - checks for `type(val) == "userdata"`
* `types.table` - checks for `type(val) == "table"`
* `types.array` - checks for table of numerically increasing indexes
* `types.integer` - checks for a number with no decimal component

Additionally there's the following helper type:

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

#### `type:repair(value)`

Attempts to repair the value recursively by using the repair callbacks
assocated with the type checker.

Retruns two values, the repaired value, and a boolean that's true if the value
neede to be repaired

If a repair took place then a copy of the value is returned. The original value
is never mutated. If a repair wasn't necessary then the original value argument
is returned unchanged.

If a repiar was required but the appropriate repair callback was not available
then a Lua error is thrown.

#### `type:is_optional()`

Returns a new type checker that matmches the same type, or `nil`.

#### `shape_type:is_open()`

This method is only available on a type checker generated by `types.shape`.

Returns a new shape type checker that won't fail if there are extra fields not
specified.

#### `type:on_repair(func)`

Returns a new type checker that matches the same type, but also has a repair
callback associated with it for when `repair` is used.

## Changelog

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

