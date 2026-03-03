-- JSON Schema generator for tableshape types
-- Transforms tableshape type definitions into JSON Schema objects
--
-- https://tour.json-schema.org/


-- this works in two passes
-- 1. simplify -> convert any complex types into their minimal type that can be serialized
-- 2. to_json_schema -> operates on common subset of types that can be directly mapped to a json shcmea


json = require "cjson"
import BaseType, types, is_type from require "tableshape.init"
import class_type, instance_type from require "tableshape.moonscript"

match_type_class = (t) ->
  assert class_type(t), "expected class type"
  types.metatable_is(types.literal t.__base)\describe "Type class: #{t.__name}"

-- directly match the type
match_type = (t) ->
  assert instance_type(t), "expected class type"
  -- NOTE: types.literal is important, so the value of mt is tested directly
  -- instead of treating it as a pattern for the mt
  types.equivalent(t) * types.metatable_is(types.literal getmetatable t)

field = (f) -> (t) -> t[f]


-- converts node to simpler type to make pattern matching eaiser
-- TODO: this needs to recurse until it stabalizes or fails
-- types.literal("hello") -> "hello"
-- strips metadata nodes: describe, annotate, tagged
-- flatten sequence of just one node

-- get field metadata from the type and store it into the state
local extract_flags
extract_flags = types.one_of({
  match_type_class(types.optional)\tag((state) -> state.optional = true) / field "base_type"
  match_type_class(types.describe)\tag((state, v) -> state.description = tostring v) / field "node"

  -- annotate is just dropped, means nothing to json schema
  match_type_class(types.annotate) / field("base_type")

  match_type_class(types._tagged_type) / field("base_type")
  match_type_class(types._tag_scope_type) / field("base_type")
}) * (types.proxy(-> extract_flags) + types.any)

local simplify
simplify = types.one_of {
  types.string
  types.number
  types.boolean

  match_type_class(types.literal) / field("value")

  types.one_of({
    match_type_class(types.describe) / field("node")
    match_type_class(types.annotate) / field("base_type")
    match_type_class(types._tagged_type) / field("base_type")
    match_type_class(types._tag_scope_type) / field("base_type")
  }) * types.proxy -> assert simplify, "missing simplify"

  -- TODO: not yet
  -- need to match out the front of the sequence
  match_type_class(types._sequence) * types.partial({
    sequence: types.array_of types.proxy(-> simplify) + types.any / nil
  }) / (res) -> assert res.sequence[1], "sequence does not have valid type"
}

json_enum = match_type_class(types.one_of) * types.scope types.partial({
-- TODO: this doesn't handle empty arrays
  options: types.array_of(simplify) * types.one_of({
    types.array_of(types.string)
    types.array_of(types.number)
  })\tag "option_literals"
}) % (t, scope) ->
  {
    type: type scope.option_literals[1] -- todo: this should be more strict
    enum: setmetatable scope.option_literals, json.array_mt
  }

local to_json_schema
to_json_schema = types.one_of {
  -- description extraction
  types.scope extract_flags * types.proxy(-> to_json_schema) % (v, flags) ->
    v.description = flags.description
    v

  json_enum

  match_type(types.any) / -> {}
  match_type(types.string) / -> { type: "string" }
  match_type(types.number) / -> { type: "number" }
  match_type(types.boolean) / -> { type: "boolean" }
  match_type(types.nil) / -> { type: "null" }
  match_type(types.function) / -> { type: "function" }
  match_type(types.table) / -> { type: "object" }
  match_type(types.array) / -> { type: "array" }
  match_type(types.integer) / -> { type: "integer" }

  match_type(types.userdata) / -> error "userdata not supported in JSON Schema"

  -- extract value from literal pattern match
  match_type_class(types.literal) / (t) -> { const: t.value }

  -- actual literal types
  types.one_of({
    types.string
    types.number
    types.boolean
  }) / (value) -> { const: value }

  types.one_of({
    match_type_class types.partial
    match_type_class types.shape
  }) * types.shape({
    open: types.any
    shape: types.shape {}, {
      extra_fields: types.scope types.map_of(
        types.string,
        types.scope (extract_flags + types.any) * types.proxy(-> to_json_schema)\tag("_type") % (v, state) ->
          -- this is a hack since we don't have general purpose visitors
          if state.description
            state._type.description = state.description
          state
      )
    }
  }) / (t) ->
    additional_properties = if t.open
      nil
    else
      false

    properties = {}
    required = {}

    for k,v in pairs t.shape
      unless v.optional
        table.insert required, k

      properties[k] = v._type

    table.sort required

    {
      type: "object"
      properties: properties
      required: setmetatable required, json.array_mt
      additionalProperties: additional_properties
    }
}


-- t = types.string * types.custom -> true

-- require("moon").p to_json_schema\transform types.shape({
--   hello: types.string\describe "poop"
--   zone: types.number\is_optional!
-- })\describe "my dodo"

{:to_json_schema, :simplify, :extract_flags}
