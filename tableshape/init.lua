local BaseType
do
  local _class_0
  local _base_0 = {
    check_value = function(self)
      return error("override me")
    end,
    check_optional = function(self, value)
      return value == nil and self.opts and self.opts.optional
    end,
    clone_opts = function(self, merge)
      local opts
      if self.opts then
        do
          local _tbl_0 = { }
          for k, v in pairs(self.opts) do
            _tbl_0[k] = v
          end
          opts = _tbl_0
        end
      else
        opts = { }
      end
      if merge then
        for k, v in pairs(merge) do
          opts[k] = v
        end
      end
      return opts
    end,
    __call = function(self, ...)
      return self:check_value(...)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "BaseType"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.is_base_type = function(self, val)
    local cls = val and val.__class
    if not (cls) then
      return false
    end
    if BaseType == cls then
      return true
    end
    return self:is_base_type(cls.__parent)
  end
  self.__inherited = function(self, cls)
    cls.__base.__call = cls.__call
  end
  BaseType = _class_0
end
local Type
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    is_optional = function(self)
      return Type(self.t, self:clone_opts({
        optional = true
      }))
    end,
    check_value = function(self, value)
      if self:check_optional(value) then
        return true
      end
      local got = type(value)
      if self.t ~= got then
        return nil, "got type `" .. tostring(got) .. "`, expected `" .. tostring(self.t) .. "`"
      end
      return true
    end,
    describe = function(self)
      return "type `" .. tostring(self.t) .. "`"
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, t, opts)
      self.t, self.opts = t, opts
    end,
    __base = _base_0,
    __name = "Type",
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
  Type = _class_0
end
local ArrayType
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    is_optional = function(self)
      return ArrayType(self:clone_opts({
        optional = true
      }))
    end,
    check_value = function(self, value)
      if self:check_optional(value) then
        return true
      end
      if not (type(value) == "table") then
        return nil, "expecting table"
      end
      local k = 1
      for i, v in pairs(value) do
        if not (type(i) == "number") then
          return nil, "non number field: " .. tostring(i)
        end
        if not (i == k) then
          return nil, "non array index, got `" .. tostring(i) .. "` but expected `" .. tostring(k) .. "`"
        end
        k = k + 1
      end
      return true
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, opts)
      self.opts = opts
    end,
    __base = _base_0,
    __name = "ArrayType",
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
  ArrayType = _class_0
end
local OneOf
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    is_optional = function(self)
      return OneOf(self.items, self:clone_opts({
        optional = true
      }))
    end,
    check_value = function(self, value)
      if self:check_optional(value) then
        return true
      end
      local _list_0 = self.items
      for _index_0 = 1, #_list_0 do
        local item = _list_0[_index_0]
        if item == value then
          return true
        end
        if item.check_value and BaseType:is_base_type(item) then
          if item:check_value(value) then
            return true
          end
        end
      end
      local err_strs
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_1 = self.items
        for _index_0 = 1, #_list_1 do
          local i = _list_1[_index_0]
          if type(i) == "table" and i.describe then
            _accum_0[_len_0] = i:describe()
          else
            _accum_0[_len_0] = "`" .. tostring(i) .. "`"
          end
          _len_0 = _len_0 + 1
        end
        err_strs = _accum_0
      end
      local err_str = table.concat(err_strs, ", ")
      return nil, "value `" .. tostring(value) .. "` did not match one of: " .. tostring(err_str)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, items, opts)
      self.items, self.opts = items, opts
      return assert(type(self.items) == "table", "expected table for items in one_of")
    end,
    __base = _base_0,
    __name = "OneOf",
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
  OneOf = _class_0
end
local ArrayOf
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    is_optional = function(self)
      return ArrayOf(self.expected, self:clone_opts({
        optional = true
      }))
    end,
    check_value = function(self, value)
      if self:check_optional(value) then
        return true
      end
      if not (type(value) == "table") then
        return nil, "expected table for array_of"
      end
      for idx, item in ipairs(value) do
        local _continue_0 = false
        repeat
          if self.expected == item then
            _continue_0 = true
            break
          end
          if self.expected.check_value and BaseType:is_base_type(self.expected) then
            local res, err = self.expected:check_value(item)
            if not (res) then
              return nil, "item " .. tostring(idx) .. " in array does not match: " .. tostring(err)
            end
          else
            return nil, "item " .. tostring(idx) .. " in array does not match `" .. tostring(self.expected) .. "`"
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return true
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, expected, opts)
      self.expected, self.opts = expected, opts
    end,
    __base = _base_0,
    __name = "ArrayOf",
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
  ArrayOf = _class_0
end
local Shape
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    is_optional = function(self)
      return Shape(self.shape, self:clone_opts({
        optional = true
      }))
    end,
    is_open = function(self)
      return Shape(self.shape, self:clone_opts({
        open = true
      }))
    end,
    check_value = function(self, value)
      if self:check_optional(value) then
        return true
      end
      if not (type(value) == "table") then
        return nil, "expecting table"
      end
      local remaining_keys
      if not (self.opts and self.opts.open) then
        do
          local _tbl_0 = { }
          for key in pairs(value) do
            _tbl_0[key] = true
          end
          remaining_keys = _tbl_0
        end
      end
      for shape_key, shape_val in pairs(self.shape) do
        local _continue_0 = false
        repeat
          local item_value = value[shape_key]
          if remaining_keys then
            remaining_keys[shape_key] = nil
          end
          if shape_val == item_value then
            _continue_0 = true
            break
          end
          if shape_val.check_value and BaseType:is_base_type(shape_val) then
            local res, err = shape_val:check_value(item_value)
            if not (res) then
              return nil, "field `" .. tostring(shape_key) .. "`: " .. tostring(err)
            end
          else
            return nil, "field `" .. tostring(shape_key) .. "` expected `" .. tostring(shape_val) .. "`"
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      if remaining_keys then
        do
          local extra_key = next(remaining_keys)
          if extra_key then
            return nil, "has extra field: `" .. tostring(extra_key) .. "`"
          end
        end
      end
      return true
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, shape, opts)
      self.shape, self.opts = shape, opts
      return assert(type(self.shape) == "table", "expected table for shape")
    end,
    __base = _base_0,
    __name = "Shape",
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
  Shape = _class_0
end
local Pattern
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    is_optional = function(self)
      return Pattern(self.pattern, self:clone_opts({
        optional = true
      }))
    end,
    check_value = function(self, value)
      if self:check_optional(value) then
        return true
      end
      do
        local initial = self.opts and self.opts.initial_type
        if initial then
          if not (type(value) == initial) then
            return nil, "expected `" .. tostring(initial) .. "`"
          end
        end
      end
      if self.opts and self.opts.coerce then
        value = tostring(value)
      end
      if not (type(value) == "string") then
        return nil, "expected string for value"
      end
      if value:match(self.pattern) then
        return true
      else
        return nil, "doesn't match pattern `" .. tostring(self.pattern) .. "`"
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, pattern, opts)
      self.pattern, self.opts = pattern, opts
    end,
    __base = _base_0,
    __name = "Pattern",
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
  Pattern = _class_0
end
local types = setmetatable({
  string = Type("string"),
  number = Type("number"),
  ["function"] = Type("function"),
  func = Type("function"),
  boolean = Type("boolean"),
  userdata = Type("userdata"),
  table = Type("table"),
  array = ArrayType(),
  integer = Pattern("^%d+$", {
    coerce = true,
    initial_type = "number"
  }),
  one_of = OneOf,
  shape = Shape,
  pattern = Pattern,
  array_of = ArrayOf
}, {
  __index = function(self, fn_name)
    return error("Type checker does not exist: `" .. tostring(fn_name) .. "`")
  end
})
local check_shape
check_shape = function(value, shape)
  assert(shape.check_value, "missing check_value method from shape")
  return shape:check_value(value)
end
return {
  check_shape = check_shape,
  types = types,
  BaseType = BaseType,
  VERSION = "1.0.0"
}
