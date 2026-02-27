-- JSON Schema generator for tableshape types
-- Transforms tableshape type definitions into JSON Schema objects
--
-- https://tour.json-schema.org/

json = require "cjson"
import BaseType, types from require "tableshape.init"
import class_type, instance_type from require "tableshape.moonscript"

match_type_class = (t) ->
  assert class_type(t), "expected class type"
  types.metatable_is(types.literal t.__base)

-- directly match the type
match_type = (t) ->
  assert instance_type(t), "expected class type"
  -- NOTE: types.literal is important, so the value of mt is tested directly instead of treating it as a pattern for the mt
  types.equivalent(t) * types.metatable_is(types.literal getmetatable t)

local to_json_schema
to_json_schema = types.one_of {
  match_type_class(types.describe) / (v) ->
    inner = to_json_schema\transform v.node
    inner.description = v._describe!
    inner

  match_type_class(types.optional) / (v) ->
    to_json_schema\transform v.base_type

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

  match_type_class(types.literal) / (t) -> { const: t }

  -- literal types
  types.one_of({
    types.string
    types.number
    types.boolean
  }) / (value) -> { const: value }

  types.one_of({
    match_type_class(types.partial)
    match_type_class(types.shape)
  }) / (t) ->
    if t.extra_fields_type
      error "extra fields not supported in JSON Schema"

    additional_properties = if t.open
      nil
    else
      false

    is_optional_type = match_type_class types.optional

    -- traverse wrapper nodes to check if type contains OptionalType
    check_optional = (node) ->
      return true if is_optional_type node
      -- DescribeNode wraps .node, OptionalType wraps .base_type
      return check_optional node.node if node.node
      return check_optional node.base_type if node.base_type
      false

    properties = {}
    required = {}
    for k,v in pairs t.shape
      properties[k] = to_json_schema\transform v
      unless check_optional v
        table.insert required, k

    {
      type: "object"
      properties: properties
      required: setmetatable required, json.array_mt
      additionalProperties: additional_properties
    }
}

-- require("moon").p to_json_schema\transform types.partial { color: types.string, height: "blue" }
-- require("moon").p to_json_schema\transform types.shape { color: types.string, height: "blue" }

-- tostring types.literal types.shape.__base

{:to_json_schema}
