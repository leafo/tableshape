local debug
debug = function(...)
  require("moon").p(...)
  return ...
end
local json = require("cjson")
local BaseType, types, is_type
do
  local _obj_0 = require("tableshape")
  BaseType, types, is_type = _obj_0.BaseType, _obj_0.types, _obj_0.is_type
end
local class_type, instance_type
do
  local _obj_0 = require("tableshape.moonscript")
  class_type, instance_type = _obj_0.class_type, _obj_0.instance_type
end
local match_type_class
match_type_class = function(t)
  assert(class_type(t), "expected class type")
  return types.metatable_is(types.literal(t.__base)):describe("Type class: " .. tostring(t.__name))
end
local match_type
match_type = function(t)
  assert(instance_type(t), "expected class type")
  return types.equivalent(t) * types.metatable_is(types.literal(getmetatable(t)))
end
local field
field = function(f)
  return function(t)
    return t[f]
  end
end
local simplify
simplify = types.one_of({
  types.string,
  types.number,
  types.boolean,
  types["nil"],
  match_type_class(types.literal) / field("value"),
  types.literal(types.any),
  types.literal(types.string),
  types.literal(types.number),
  types.literal(types.boolean),
  types.literal(types["nil"]),
  types.literal(types["function"]),
  types.literal(types.table),
  types.literal(types.array),
  types.literal(types.integer),
  match_type_class(types.shape),
  match_type_class(types.partial),
  match_type_class(types.array_of),
  match_type_class(types.map_of),
  types.one_of({
    match_type_class(types.optional):tag(function(state)
      state.optional = true
    end) / field("base_type"),
    match_type_class(types.describe):tag(function(state, v)
      state.description = state.description or tostring(v)
    end) / field("node"),
    match_type_class(types._transform) / field("node"),
    match_type_class(types.annotate) / field("base_type"),
    match_type_class(types._tagged_type) / field("base_type"),
    match_type_class(types._tag_scope_type) / field("base_type")
  }) * types.proxy(function()
    return assert(simplify, "missing simplify")
  end),
  match_type_class(types.one_of) * types.one_of({
    types.partial({
      options = types.array_of(types.proxy(function()
        return simplify
      end)) * types.one_of({
        types.array_of(types.string),
        types.array_of(types.number)
      })
    }) / function(v)
      return types.one_of(v.options)
    end,
    types.partial({
      options = types.array_of(types.proxy(function()
        return simplify
      end) + types.any / nil)
    }) / function(res)
      return assert(res.options[1], "options do not have valid type")
    end
  }),
  match_type_class(types._sequence) * types.partial({
    sequence = types.array_of(types.proxy(function()
      return simplify
    end) + types.any / nil)
  }) / function(res)
    return assert(res.sequence[1], "sequence does not have valid type")
  end
})
local not_optional = types.custom(function(val, state)
  if state and state.optional then
    return nil, "expected non-optional type"
  end
  return true
end)
local not_optional_simplified = types.scope(simplify * not_optional)
local with_description
with_description = function(t)
  return types.scope(t % function(v, state)
    if state then
      if state.optional then
        error("unhandled optional state on type")
      end
      v.description = state.description
    end
    return v
  end)
end
local json_schema_value
json_schema_value = simplify * types.one_of({
  match_type(types.any) / function()
    return { }
  end,
  match_type(types.string) / function()
    return {
      type = "string"
    }
  end,
  match_type(types.number) / function()
    return {
      type = "number"
    }
  end,
  match_type(types.boolean) / function()
    return {
      type = "boolean"
    }
  end,
  match_type(types["nil"]) / function()
    return {
      type = "null"
    }
  end,
  match_type(types["function"]) / function()
    return {
      type = "function"
    }
  end,
  match_type(types.table) / function()
    return {
      type = "object"
    }
  end,
  match_type(types.array) / function()
    return {
      type = "array"
    }
  end,
  match_type(types.integer) / function()
    return {
      type = "integer"
    }
  end,
  match_type(types.userdata) / function()
    return error("userdata not supported in JSON Schema")
  end,
  match_type_class(types.literal) / function(t)
    return {
      const = t.value
    }
  end,
  types.one_of({
    types.string,
    types.number,
    types.boolean
  }) / function(value)
    return {
      const = value
    }
  end,
  match_type_class(types.one_of) * types.partial({
    options = types.one_of({
      types.array_of(types.string),
      types.array_of(types.number)
    })
  }) / function(v)
    return {
      type = type(v.options[1]),
      enum = setmetatable(v.options, json.array_mt)
    }
  end,
  types.one_of({
    match_type_class(types.partial),
    match_type_class(types.shape)
  }) * types.shape({
    open = types.any,
    shape = types.shape({ }, {
      extra_fields = types.map_of(types.string, types.scope(types.proxy(function()
        return json_schema_value
      end) % function(v, state)
        state = state or { }
        v.description = state.description
        state._type = v
        return state
      end))
    })
  }) / function(t)
    local additional_properties
    if t.open then
      additional_properties = nil
    else
      additional_properties = false
    end
    local properties = { }
    local required = { }
    for k, v in pairs(t.shape) do
      if not (v.optional) then
        table.insert(required, k)
      end
      properties[k] = v._type
    end
    table.sort(required)
    return {
      type = "object",
      properties = properties,
      required = setmetatable(required, json.array_mt),
      additionalProperties = additional_properties
    }
  end,
  match_type_class(types.array_of) * types.partial({
    expected = types.scope(types.proxy(function()
      return json_schema_value
    end) * not_optional),
    length_type = types.one_of({
      not_optional_simplified * types.number / function(v)
        return {
          min_items = v,
          max_items = v
        }
      end,
      match_type_class(types.range) * types.partial({
        left = not_optional_simplified * types.number,
        right = not_optional_simplified * types.number
      }) / function(v)
        return {
          min_items = v.left,
          max_items = v.right
        }
      end,
      types.any / nil
    })
  }) / function(v)
    return {
      type = "array",
      items = v.expected,
      minItems = v.length_type and v.length_type.min_items,
      maxItems = v.length_type and v.length_type.max_items
    }
  end,
  match_type_class(types.map_of) * types.partial({
    expected_key = not_optional_simplified * match_type(types.string),
    expected_value = types.scope(types.proxy(function()
      return json_schema_value
    end) * not_optional)
  }) / function(v)
    return {
      type = "object",
      additionalProperties = v.expected_value
    }
  end
})
local to_json_schema = with_description(json_schema_value)
return {
  to_json_schema = to_json_schema,
  simplify = simplify
}
