-- JSON Schema generator for tableshape types
-- Transforms tableshape type definitions into JSON Schema objects

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

to_json_schema = types.one_of {
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
}


{:to_json_schema}
