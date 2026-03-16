# `tableshape.ext.json_schema`

`tableshape.ext.json_schema` is an extension for generating JSON Schema from a useful subset of tableshape types.

It is intended for cases where a tableshape type should be exposed to another system, such as a JavaScript interface that wants argument metadata.

This module does not try to provide a complete 1:1 mapping between tableshape and JSON Schema. The goal is to communicate the high-level intent of common types in a form that is useful to downstream consumers.

## Requiring The Module

```lua
local json_schema = require("tableshape.ext.json_schema")

local to_json_schema = json_schema.to_json_schema
local JsonSchema = json_schema.JsonSchema
```

## Exports

### `to_json_schema`

A tableshape transform that converts a supported type into a Lua table representing a JSON Schema object.

```lua
local types = require("tableshape").types
local to_json_schema = require("tableshape.ext.json_schema").to_json_schema

local schema = assert(to_json_schema:transform(types.string))
-- { type = "string" }
```

### `JsonSchema`

A wrapper type that lets you provide a custom schema for a type.

It behaves like the wrapped type for validation, but when exported to JSON Schema it returns the schema you supplied.

```lua
local types = require("tableshape").types
local JsonSchema = require("tableshape.ext.json_schema").JsonSchema

local t = JsonSchema(types.string, {
  type = "string",
  format = "email"
})
```

You can also provide a function instead of a table. The wrapped type is passed as the first argument.

```lua
local t = JsonSchema(types.string, function(base_type)
  return {
    type = "string",
    title = tostring(base_type)
  }
end)
```

The returned schema table is cloned before outer metadata like `describe(...)` is applied.

## Basic Usage

### Primitives

```lua
local types = require("tableshape").types
local to_json_schema = require("tableshape.ext.json_schema").to_json_schema

assert.same({ type = "string" }, to_json_schema:transform(types.string))
assert.same({ type = "number" }, to_json_schema:transform(types.number))
assert.same({ type = "boolean" }, to_json_schema:transform(types.boolean))
assert.same({ type = "null" }, to_json_schema:transform(types["nil"]))
```

### Shapes

```lua
local user_type = types.shape({
  name = types.string,
  age = types.number:is_optional()
})

local schema = assert(to_json_schema:transform(user_type))

-- {
--   type = "object",
--   properties = {
--     name = { type = "string" },
--     age = { type = "number" }
--   },
--   required = { "name" },
--   additionalProperties = false
-- }
```

Optional object fields are represented by omission from `required`.

### Partials

`types.partial(...)` is exported as an open object schema.

Its named fields are still exported as normal properties, but unlike `shape`, the exporter does not force `additionalProperties = false`.

```lua
local user_patch = types.partial({
  name = types.string,
  age = types.number
})

local schema = assert(to_json_schema:transform(user_patch))

-- {
--   type = "object",
--   properties = {
--     name = { type = "string" },
--     age = { type = "number" }
--   },
--   required = { "age", "name" }
-- }
```

### Arrays

```lua
local tags_type = types.array_of(types.string)

assert.same({
  type = "array",
  items = { type = "string" }
}, to_json_schema:transform(tags_type))
```

If an `array_of` type uses a direct numeric length or a basic numeric `types.range(...)` for its `length`, those are mapped to `minItems` and `maxItems`.

```lua
local tags_type = types.array_of(types.string, {
  length = types.range(1, 3)
})

-- {
--   type = "array",
--   items = { type = "string" },
--   minItems = 1,
--   maxItems = 3
-- }
```

### Maps

`map_of` is supported only for string-keyed maps.

```lua
local metadata_type = types.map_of(types.string, types.number)

assert.same({
  type = "object",
  additionalProperties = { type = "number" }
}, to_json_schema:transform(metadata_type))
```

## Supported Patterns

The exporter currently has direct support for the most common cases:

- primitive types like `string`, `number`, `boolean`, `nil`, `integer`
- literals via `const`
- string and number enums via `enum`
- `shape` and `partial`
- `array_of`
- `map_of(types.string, value_type)`
- wrapped descriptions via `describe(...)`
- custom overrides via `JsonSchema(...)`

Some wrapped or transformed types from other libraries also serialize cleanly because they simplify down to one of the supported cases.

## Important Limitations

This extension intentionally does not try to serialize every tableshape construct.

In particular:

- unsupported types may return `nil`
- some complex unions and sequences are reduced to a simpler interpretation instead of being exported exactly
- top-level "optional" semantics do not have a standard JSON Schema representation
- this is not intended to be a full semantic model of tableshape

If you need a specific schema shape that the exporter does not support, use `JsonSchema(...)` to provide it explicitly.

## Recommended Use

Use this module when you want a reasonable JSON Schema description for a tableshape type, especially for API metadata, tool arguments, or JavaScript-side interfaces.

If exact emitted schema matters more than inferred intent, wrap the type with `JsonSchema(...)` and provide the schema directly.
