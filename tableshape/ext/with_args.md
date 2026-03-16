# `tableshape.ext.with_args`

`tableshape.ext.with_args` is an extension for wrapping functions with
tableshape-based argument validation and transformation. Note that extension
modules are not fully finalized and may have breaking changes in future updates.

It is intended for cases where you want to enforce type contracts on function
arguments at runtime, with optional transformation of values before they reach
the function body.

## Requiring The Module

```lua
local with_args = require("tableshape.ext.with_args").with_args
```

## `with_args(arg_types, fn)`

Wraps `fn` so that its arguments are validated (and optionally transformed)
according to `arg_types` before the function is called.

- `arg_types` — a table of positional type specs plus optional named fields
- `fn` — the function to wrap

Returns a new function with the same signature as `fn`.

### Positional Types

The array part of `arg_types` defines the expected type for each positional
argument. Each entry can be a tableshape type or a literal value (which is
automatically wrapped with `types.literal`).

```lua
local types = require("tableshape").types
local with_args = require("tableshape.ext.with_args").with_args

local add = with_args({
  types.number,
  types.number
}, function(a, b)
  return a + b
end)

print(add(1, 2))   -- 3
print(add(1, "x")) -- nil, 'argument 2: expected type "number", got "string"'
```

Literal values are matched exactly:

```lua
local greet = with_args({
  "hello",
  types.string
}, function(greeting, name)
  return greeting .. " " .. name
end)

print(greet("hello", "world")) -- hello world
print(greet("hi", "world"))    -- nil, 'argument 1: expected "hello"'
```

### Error Handling

By default, validation failures return `nil` followed by an error message.
Set `assert = true` in `arg_types` to throw an error instead:

```lua
local strict_add = with_args({
  assert = true,
  types.number,
  types.number
}, function(a, b)
  return a + b
end)

strict_add(1, "x") -- error: argument 2: expected type "number", got "string"
```

### Transforms

Because validation uses `transform` internally, any tableshape transform
attached to a type is applied before the argument reaches the wrapped function:

```lua
local shout = with_args({
  types.string / string.upper
}, function(msg)
  return msg
end)

print(shout("hello")) -- HELLO
```

### Rest Arguments

Use the `rest` field to validate all arguments beyond the positional ones.
Like positional types, `rest` accepts a tableshape type or a literal value.

```lua
local log = with_args({
  rest = types.string,
  types.number  -- log level
}, function(level, ...)
  print(level, ...)
end)

log(1, "hello", "world")  -- ok
log(1, "hello", 42)       -- nil, 'argument 3 (rest): expected type "string", got "number"'
```

Transforms also work on rest arguments:

```lua
local log = with_args({
  rest = types.string / string.upper,
  types.number
}, function(level, ...)
  return ...
end)

print(log(1, "hello", "world")) -- HELLO   WORLD
```

When no `rest` type is specified, extra arguments are passed through unchanged.

### Optional Arguments

Use `is_optional()` on a type to allow `nil` for that position:

```lua
local greet = with_args({
  types.string,
  types.string:is_optional()
}, function(name, title)
  if title then
    return title .. " " .. name
  end
  return name
end)

print(greet("Alice"))          -- Alice
print(greet("Alice", "Dr."))   -- Dr. Alice
```

### Missing Arguments

Arguments that are not provided are seen as `nil` and validated against the
expected type. A required type will reject them:

```lua
local add = with_args({
  types.number,
  types.number
}, function(a, b)
  return a + b
end)

print(add(1)) -- nil, 'argument 2: expected type "number", got "nil"'
```

### Complex Types

Any tableshape type works as an argument spec, including shapes:

```lua
local create_user = with_args({
  types.shape({
    name = types.string,
    age = types.number
  })
}, function(user)
  return user.name .. " is " .. user.age
end)

print(create_user({ name = "Alice", age = 30 }))
-- Alice is 30

print(create_user({ name = "Alice", age = "thirty" }))
-- nil, 'argument 1: field "age": expected type "number", got "string"'
```

## Return Values

The wrapped function preserves all return values from the original function,
including multiple returns.

```lua
local swap = with_args({
  types.number,
  types.number
}, function(a, b)
  return b, a
end)

print(swap(1, 2)) -- 2   1
```
