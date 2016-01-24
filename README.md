
# tableshape

A Lua library for verifying the shape (schema, structure, etc.) of a table.
It's inspired by the [PropTypes module of
React](https://facebook.github.io/react/docs/reusable-components.html#prop-validation).

### Usage

```lua
local types = require("tableshape").types

-- define the shape of our player object
local player_shape = types.shape {
  class = types.one_of{"player", "enemy"},
  name = types.string,
  position = types.shape{
    x = types.number,
    y = types.number,
  },
  inventory = types.array_of(types.shape {
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
assert(types.string:check_value("hello!")) -- an error: got type `number`, expected `string`
```

You can see the full list of the available types below in the reference.

The real power of `tableshape` comes from the ability to describe complex types
by nesting the type checkers.

Here we test for an array of numbers by using `array_of`:

```lua
local numbers_shape = types.array_of(types.number)

assert(numbers_shape:check_value({1,2,3}))
assert(numbers_shape:check_value({1,"oops",3})) -- error: item 2 in array does not match: got type `string`, expected `number`
```

> Note: The type checking is strict, a string that looks like a number `"123"`
> is not a number and will trigger an error!

The structure of a hashtable can be tested with `types.shape`. It takes a hash
table where the key is the field to check, and the value is the type checker:

```lua
local object_shape = types.shape {
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
except `nil` as a value. The first error stops the rest of the type check, and
is returned as the second return value.

You can also use a literal value to match it directly:

```lua
local object_shape = types.shape {
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

## Reference

```lua
local types = require("tableshape").types
```

### Compound constructors

### Types


