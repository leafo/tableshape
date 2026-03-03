local json = require("cjson")
local BaseType, types, is_type
do
  local _obj_0 = require("tableshape.init")
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
local extract_flags
extract_flags = types.one_of({
  match_type_class(types.optional):tag(function(state)
    state.optional = true
  end) / field("base_type"),
  match_type_class(types.describe):tag(function(state, v)
    state.description = tostring(v)
  end) / field("node"),
  match_type_class(types.annotate) / field("base_type"),
  match_type_class(types._tagged_type) / field("base_type"),
  match_type_class(types._tag_scope_type) / field("base_type")
}) * (types.proxy(function()
  return extract_flags
end) + types.any)
local simplify
simplify = types.one_of({
  types.string,
  types.number,
  types.boolean,
  match_type_class(types.literal) / field("value"),
  types.one_of({
    match_type_class(types.describe) / field("node"),
    match_type_class(types.annotate) / field("base_type"),
    match_type_class(types._tagged_type) / field("base_type"),
    match_type_class(types._tag_scope_type) / field("base_type")
  }) * types.proxy(function()
    return assert(simplify, "missing simplify")
  end),
  match_type_class(types._sequence) * types.partial({
    sequence = types.array_of(types.proxy(function()
      return simplify
    end) + types.any / nil)
  }) / function(res)
    return assert(res.sequence[1], "sequence does not have valid type")
  end
})
local json_enum = match_type_class(types.one_of) * types.scope(types.partial({
  options = types.array_of(simplify) * types.one_of({
    types.array_of(types.string),
    types.array_of(types.number)
  }):tag("option_literals")
}) % function(t, scope)
  return {
    type = type(scope.option_literals[1]),
    enum = setmetatable(scope.option_literals, json.array_mt)
  }
end)
local to_json_schema
to_json_schema = types.one_of({
  types.scope(extract_flags * types.proxy(function()
    return to_json_schema
  end) % function(v, flags)
    v.description = flags.description
    return v
  end),
  json_enum,
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
  types.one_of({
    match_type_class(types.partial),
    match_type_class(types.shape)
  }) * types.shape({
    open = types.any,
    shape = types.shape({ }, {
      extra_fields = types.scope(types.map_of(types.string, types.scope((extract_flags + types.any) * types.proxy(function()
        return to_json_schema
      end):tag("_type") % function(v, state)
        if state.description then
          state._type.description = state.description
        end
        return state
      end)))
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
  end
})
return {
  to_json_schema = to_json_schema,
  simplify = simplify,
  extract_flags = extract_flags
}
