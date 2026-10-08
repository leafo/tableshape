local json = require("cjson")
local BaseType, types, FailedTransform
do
  local _obj_0 = require("tableshape")
  BaseType, types, FailedTransform = _obj_0.BaseType, _obj_0.types, _obj_0.FailedTransform
end
local Literal = types.literal
local Shape = types.shape
local Partial = types.partial
local ArrayOf = types.array_of
local MapOf = types.map_of
local OneOf = types.one_of
local Range = types.range
local OptionalType = types.optional
local DescribeNode = types.describe
local TransformNode = types._transform
local AnnotateNode = types.annotate
local TaggedType = types._tagged_type
local TagScopeType = types._tag_scope_type
local SequenceNode = types._sequence
local FirstOfNode = types._first_of
local JsonSchema
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    _transform = function(self, ...)
      return self.base_type:_transform(...)
    end,
    _describe = function(self)
      return self.base_type:_describe()
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, base_type, schema)
      self.base_type, self.schema = base_type, schema
      assert(BaseType:is_base_type(self.base_type), "expected a type checker")
      return assert(type(self.schema) == "table" or type(self.schema) == "function", "expected table or function for schema")
    end,
    __base = _base_0,
    __name = "JsonSchema",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  JsonSchema = _class_0
end
local basic_types = {
  [types.any] = "any",
  [types.string] = "string",
  [types.number] = "number",
  [types.boolean] = "boolean",
  [types["nil"]] = "null",
  [types["function"]] = "function",
  [types.table] = "object",
  [types.array] = "array",
  [types.integer] = "integer"
}
local passthrough_classes = {
  [Shape] = true,
  [Partial] = true,
  [ArrayOf] = true,
  [MapOf] = true,
  [JsonSchema] = true
}
local unwrap_classes = {
  [TransformNode] = "node",
  [AnnotateNode] = "base_type",
  [TaggedType] = "base_type",
  [TagScopeType] = "base_type"
}
local class_of
class_of = function(t)
  local mt = getmetatable(t)
  return mt and mt.__class
end
local simplify
simplify = function(t, state)
  local _exp_0 = type(t)
  if "string" == _exp_0 or "number" == _exp_0 or "boolean" == _exp_0 or "nil" == _exp_0 then
    return t, true
  elseif "table" == _exp_0 then
    local _scrap_0 = nil
  else
    return nil, false
  end
  if basic_types[t] then
    return t, true
  end
  local cls = class_of(t)
  if not (cls) then
    return nil, false
  end
  if cls == Literal then
    return t.value, true
  end
  if passthrough_classes[cls] then
    return t, true
  end
  if cls == OptionalType then
    state.optional = true
    return simplify(t.base_type, state)
  end
  if cls == DescribeNode then
    state.description = state.description or tostring(t)
    return simplify(t.node, state)
  end
  do
    local field = unwrap_classes[cls]
    if field then
      return simplify(t[field], state)
    end
  end
  if cls == OneOf then
    local simplified = { }
    local all_strings, all_numbers = true, true
    local all_ok = true
    local _list_0 = t.options
    for _index_0 = 1, #_list_0 do
      local opt = _list_0[_index_0]
      local v, ok = simplify(opt, state)
      if ok then
        if v ~= nil then
          table.insert(simplified, v)
        end
        if type(v) ~= "string" then
          all_strings = false
        end
        if type(v) ~= "number" then
          all_numbers = false
        end
      else
        all_ok = false
      end
    end
    if all_ok and #simplified == #t.options and (all_strings or all_numbers) then
      return OneOf(simplified), true
    end
    return (assert(simplified[1], "options do not have valid type")), true
  end
  if cls == SequenceNode then
    local first = nil
    local _list_0 = t.sequence
    for _index_0 = 1, #_list_0 do
      local item = _list_0[_index_0]
      local v, ok = simplify(item, state)
      if ok and v ~= nil and first == nil then
        first = v
      end
    end
    return (assert(first, "sequence does not have valid type")), true
  end
  if cls == FirstOfNode then
    if not (#t.options == 2) then
      return nil, false
    end
    local a, ok = simplify(t.options[1], { })
    if not (ok and a == types["nil"]) then
      return nil, false
    end
    local b
    b, ok = simplify(t.options[2], { })
    if not (ok) then
      return nil, false
    end
    state.optional = true
    return simplify(b, state)
  end
  return nil, false
end
local json_schema_value
json_schema_value = function(t, state)
  local v, ok = simplify(t, state)
  if not (ok) then
    return nil, "unsupported type"
  end
  local _exp_0 = type(v)
  if "string" == _exp_0 or "number" == _exp_0 or "boolean" == _exp_0 then
    return {
      const = v
    }, true
  elseif "table" == _exp_0 then
    local _scrap_0 = nil
  else
    return nil, "unsupported value"
  end
  do
    local name = basic_types[v]
    if name then
      return ((function()
        if name == "any" then
          return { }
        else
          return {
            type = name
          }
        end
      end)()), true
    end
  end
  local cls = class_of(v)
  if cls == JsonSchema then
    local schema
    local _exp_1 = type(v.schema)
    if "function" == _exp_1 then
      schema = v.schema(v.base_type)
    else
      schema = v.schema
    end
    assert(type(schema) == "table", "expected table for schema")
    local copy
    do
      local _tbl_0 = { }
      for k, sv in pairs(schema) do
        _tbl_0[k] = sv
      end
      copy = _tbl_0
    end
    do
      local mt = getmetatable(schema)
      if mt then
        setmetatable(copy, mt)
      end
    end
    return copy, true
  end
  if cls == Literal then
    return {
      const = v.value
    }, true
  end
  if cls == OneOf then
    local options = v.options
    if options[1] == nil then
      return nil, "empty enum"
    end
    return {
      type = type(options[1]),
      enum = setmetatable((function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #options do
          local o = options[_index_0]
          _accum_0[_len_0] = o
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), json.array_mt)
    }, true
  end
  if cls == Shape or cls == Partial then
    local properties = { }
    local required = { }
    for k, field_type in pairs(v.shape) do
      if not (type(k) == "string") then
        return nil, "shape key is not a string"
      end
      local field_state = { }
      local schema, err = json_schema_value(field_type, field_state)
      if not (schema) then
        return nil, tostring(k) .. ": " .. tostring(err)
      end
      schema.description = field_state.description
      properties[k] = schema
      if not (field_state.optional) then
        table.insert(required, k)
      end
    end
    table.sort(required)
    return {
      type = "object",
      properties = properties,
      required = setmetatable(required, json.array_mt),
      additionalProperties = (function()
        if v.open then
          return nil
        else
          return false
        end
      end)()
    }, true
  end
  if cls == ArrayOf then
    local item_state = { }
    local items, err = json_schema_value(v.expected, item_state)
    if not (items) then
      return nil, "array item: " .. tostring(err)
    end
    if item_state.optional then
      return nil, "array item: unexpected optional type"
    end
    local min_items, max_items
    do
      local length_type = v.length_type
      if length_type then
        local length_state = { }
        local length
        length, ok = simplify(length_type, length_state)
        if ok and not length_state.optional and type(length) == "number" then
          min_items, max_items = length, length
        elseif class_of(length_type) == Range then
          local left, left_ok = simplify(length_type.left, { })
          local right, right_ok = simplify(length_type.right, { })
          if left_ok and right_ok and type(left) == "number" and type(right) == "number" then
            min_items, max_items = left, right
          end
        end
      end
    end
    return {
      type = "array",
      items = items,
      minItems = min_items,
      maxItems = max_items
    }, true
  end
  if cls == MapOf then
    local key_state = { }
    local key
    key, ok = simplify(v.expected_key, key_state)
    if not (ok and not key_state.optional and key == types.string) then
      return nil, "map key must be string"
    end
    local value_state = { }
    local value_schema, err = json_schema_value(v.expected_value, value_state)
    if not (value_schema) then
      return nil, "map value: " .. tostring(err)
    end
    if value_state.optional then
      return nil, "map value: unexpected optional type"
    end
    return {
      type = "object",
      additionalProperties = value_schema
    }, true
  end
  return nil, "unsupported type"
end
local ToJsonSchema
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    _transform = function(self, t, state)
      local schema_state = { }
      local schema, err = json_schema_value(t, schema_state)
      if not (schema) then
        return FailedTransform, "could not convert to json schema: " .. tostring(err)
      end
      if schema_state.optional then
        error("unhandled optional state on type")
      end
      schema.description = schema_state.description
      return schema, state
    end,
    _describe = function(self)
      return "json schema"
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "ToJsonSchema",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ToJsonSchema = _class_0
end
local Simplify
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    _transform = function(self, t, state)
      local v, ok = simplify(t, { })
      if not (ok) then
        return FailedTransform, "could not simplify type"
      end
      return v, state
    end,
    _describe = function(self)
      return "simplified type"
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "Simplify",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Simplify = _class_0
end
local to_json_schema = ToJsonSchema()
return {
  to_json_schema = to_json_schema,
  simplify = Simplify(),
  JsonSchema = JsonSchema
}
