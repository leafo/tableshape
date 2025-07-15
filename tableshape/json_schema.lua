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
local to_json_schema = types.one_of({
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
  end
})
return {
  to_json_schema = to_json_schema
}
