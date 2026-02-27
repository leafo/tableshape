local json = require("cjson")
local BaseType, types
do
  local _obj_0 = require("tableshape.init")
  BaseType, types = _obj_0.BaseType, _obj_0.types
end
local class_type, instance_type
do
  local _obj_0 = require("tableshape.moonscript")
  class_type, instance_type = _obj_0.class_type, _obj_0.instance_type
end
local match_type_class
match_type_class = function(t)
  assert(class_type(t), "expected class type")
  return types.metatable_is(types.literal(t.__base))
end
local match_type
match_type = function(t)
  assert(instance_type(t), "expected class type")
  return types.equivalent(t) * types.metatable_is(types.literal(getmetatable(t)))
end
local to_json_schema
to_json_schema = types.one_of({
  match_type_class(types.describe) / function(v)
    local inner = to_json_schema:transform(v.node)
    inner.description = v._describe()
    return inner
  end,
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
      const = t
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
  }) / function(t)
    if t.extra_fields_type then
      error("extra fields not supported in JSON Schema")
    end
    local additional_properties
    if t.open then
      additional_properties = nil
    else
      additional_properties = false
    end
    local properties = { }
    local required = { }
    for k, v in pairs(t.shape) do
      properties[k] = to_json_schema:transform(v)
      table.insert(required, k)
    end
    return {
      type = "object",
      properties = properties,
      required = setmetatable(required, json.array_mt),
      additionalProperties = additional_properties
    }
  end
})
return {
  to_json_schema = to_json_schema
}
