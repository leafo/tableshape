local BaseType
do
  local _class_0
  local _base_0 = {
    check_value = function(self)
      return error("override me")
    end,
    repair = function(self, val, fix_fn)
      local fixed = false
      local pass, err = self:check_value(val)
      if not (pass) then
        fix_fn = fix_fn or (self.opts and self.opts.repair)
        assert(fix_fn, "missing repair function for: " .. tostring(err))
        fixed = true
        val = fix_fn(val, err)
      end
      return val, fixed
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
    if not (type(val) == "table") then
      return false
    end
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
local AnyType
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    check_value = function(self)
      return true
    end,
    is_optional = function(self)
      return AnyType
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "AnyType",
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
  AnyType = _class_0
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
    on_repair = function(self, repair_fn)
      return Type(self.t, self:clone_opts({
        repair = repair_fn
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
    on_repair = function(self, repair_fn)
      return ArrayType(self:clone_opts({
        repair = repair_fn
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
    on_repair = function(self, repair_fn)
      return OneOf(self.items, self:clone_opts({
        repair = repair_fn
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
        if BaseType:is_base_type(item) and item.check_value then
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
    on_repair = function(self, repair_fn)
      return ArrayOf(self.expected, self:clone_opts({
        repair = repair_fn
      }))
    end,
    repair = function(self, tbl, repair_fn)
      if self:check_optional(tbl) then
        return tbl, false
      end
      if not (type(tbl) == "table") then
        local fix_fn = fix_fn or (self.opts and self.opts.repair)
        assert(fix_fn, "missing repair function for: " .. tostring(self.__class.type_err_message))
        return fix_fn("table_invalid", self.__class.type_err_message, tbl), true
      end
      local fixed = false
      local copy
      if BaseType:is_base_type(self.expected) and self.expected.repair then
        for idx, item in ipairs(tbl) do
          local item_value, item_fixed = self.expected:repair(item)
          if item_fixed then
            fixed = true
            copy = copy or (function()
              local _accum_0 = { }
              local _len_0 = 1
              local _max_0 = (idx - 1)
              for _index_0 = 1, _max_0 < 0 and #tbl + _max_0 or _max_0 do
                local v = tbl[_index_0]
                _accum_0[_len_0] = v
                _len_0 = _len_0 + 1
              end
              return _accum_0
            end)()
            if item_value ~= nil then
              table.insert(copy, item_value)
            end
          else
            if copy then
              table.insert(copy, item)
            end
          end
        end
      else
        for idx, item in ipairs(tbl) do
          local pass, err = self:check_field(shape_key, item_value, shape_val, tbl)
          if pass then
            if copy then
              table.insert(copy, item)
            end
          else
            local fix_fn = fix_fn or (self.opts and self.opts.repair)
            assert(fix_fn, "missing repair function for: " .. tostring(err))
            fixed = true
            copy = copy or (function()
              local _accum_0 = { }
              local _len_0 = 1
              local _max_0 = (idx - 1)
              for _index_0 = 1, _max_0 < 0 and #tbl + _max_0 or _max_0 do
                local v = tbl[_index_0]
                _accum_0[_len_0] = v
                _len_0 = _len_0 + 1
              end
              return _accum_0
            end)()
            table.insert(copy, fix_fn("field_invalid", idx, item))
          end
        end
      end
      return copy or tbl, fixed
    end,
    check_field = function(self, key, value, tbl)
      if value == self.expected then
        return true
      end
      if BaseType:is_base_type(self.expected) and self.expected.check_value then
        local res, err = self.expected:check_value(value)
        if not (res) then
          return nil, "item " .. tostring(key) .. " in array does not match: " .. tostring(err)
        end
      else
        return nil, "item " .. tostring(key) .. " in array does not match `" .. tostring(self.expected) .. "`"
      end
      return true
    end,
    check_value = function(self, value)
      if self:check_optional(value) then
        return true
      end
      if not (type(value) == "table") then
        return nil, "expected table for array_of"
      end
      for idx, item in ipairs(value) do
        local pass, err = self:check_field(idx, item, value)
        if not (pass) then
          return nil, err
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
  local self = _class_0
  self.type_err_message = "expecting table"
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ArrayOf = _class_0
end
local MapOf
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    is_optional = function(self)
      return MapOf(self.expected_key, self.expected_value, self:clone_opts({
        optional = true
      }))
    end,
    on_repair = function(self, repair_fn)
      return MapOf(self.expected_key, self.expected_value, self:clone_opts({
        repair = repair_fn
      }))
    end,
    check_value = function(self, value)
      if self:check_optional(value) then
        return true
      end
      if not (type(value) == "table") then
        return nil, "expected table for map_of"
      end
      for k, v in pairs(value) do
        if self.expected_key.check_value then
          local res, err = self.expected_key:check_value(k)
          if not (res) then
            return nil, "field `" .. tostring(k) .. "` in table does not match: " .. tostring(err)
          end
        else
          if not (self.expected_key == k) then
            return nil, "field `" .. tostring(k) .. "` does not match `" .. tostring(self.expected_key) .. "`"
          end
        end
        if self.expected_value.check_value then
          local res, err = self.expected_value:check_value(v)
          if not (res) then
            return nil, "field `" .. tostring(k) .. "` value in table does not match: " .. tostring(err)
          end
        else
          if not (self.expected_value == v) then
            return nil, "field `" .. tostring(k) .. "` value does not match `" .. tostring(self.expected_value) .. "`"
          end
        end
      end
      return true
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, expected_key, expected_value, opts)
      self.expected_key, self.expected_value, self.opts = expected_key, expected_value, opts
    end,
    __base = _base_0,
    __name = "MapOf",
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
  MapOf = _class_0
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
    on_repair = function(self, repair_fn)
      return Shape(self.shape, self:clone_opts({
        repair = repair_fn
      }))
    end,
    is_open = function(self)
      return Shape(self.shape, self:clone_opts({
        open = true
      }))
    end,
    repair = function(self, tbl, fix_fn)
      if self:check_optional(tbl) then
        return tbl, false
      end
      if not (type(tbl) == "table") then
        fix_fn = fix_fn or (self.opts and self.opts.repair)
        assert(fix_fn, "missing repair function for: " .. tostring(self.__class.type_err_message))
        return fix_fn("table_invalid", self.__class.type_err_message, tbl), true
      end
      local fixed = false
      local remaining_keys
      if not (self.opts and self.opts.open) then
        do
          local _tbl_0 = { }
          for key in pairs(tbl) do
            _tbl_0[key] = true
          end
          remaining_keys = _tbl_0
        end
      end
      local copy
      for shape_key, shape_val in pairs(self.shape) do
        local item_value = tbl[shape_key]
        if remaining_keys then
          remaining_keys[shape_key] = nil
        end
        if BaseType:is_base_type(shape_val) and shape_val.repair then
          local field_value, field_fixed = shape_val:repair(item_value)
          if field_fixed then
            copy = copy or (function()
              local _tbl_0 = { }
              for k, v in pairs(tbl) do
                _tbl_0[k] = v
              end
              return _tbl_0
            end)()
            fixed = true
            copy[shape_key] = field_value
          end
        else
          local pass, err = self:check_field(shape_key, item_value, shape_val, tbl)
          if not (pass) then
            fix_fn = fix_fn or (self.opts and self.opts.repair)
            assert(fix_fn, "missing repair function for: " .. tostring(err))
            fixed = true
            copy = copy or (function()
              local _tbl_0 = { }
              for k, v in pairs(tbl) do
                _tbl_0[k] = v
              end
              return _tbl_0
            end)()
            copy[shape_key] = fix_fn("field_invalid", shape_key, item_value, err, shape_val)
          end
        end
      end
      if remaining_keys and next(remaining_keys) then
        fix_fn = fix_fn or (self.opts and self.opts.repair)
        copy = copy or (function()
          local _tbl_0 = { }
          for k, v in pairs(tbl) do
            _tbl_0[k] = v
          end
          return _tbl_0
        end)()
        assert(fix_fn, "missing repair function for: extra field")
        for k in pairs(remaining_keys) do
          fixed = true
          copy[k] = fix_fn("extra_field", k, copy[k])
        end
      end
      return copy or tbl, fixed
    end,
    check_field = function(self, key, value, expected_value, tbl)
      if value == expected_value then
        return true
      end
      if BaseType:is_base_type(expected_value) and expected_value.check_value then
        local res, err = expected_value:check_value(value)
        if not (res) then
          return nil, "field `" .. tostring(key) .. "`: " .. tostring(err)
        end
      else
        return nil, "field `" .. tostring(key) .. "` expected `" .. tostring(expected_value) .. "`, got `" .. tostring(value) .. "`"
      end
      return true
    end,
    check_value = function(self, value)
      if self:check_optional(value) then
        return true
      end
      if not (type(value) == "table") then
        return nil, self.__class.type_err_message
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
        local item_value = value[shape_key]
        if remaining_keys then
          remaining_keys[shape_key] = nil
        end
        local pass, err = self:check_field(shape_key, item_value, shape_val, value)
        if not (pass) then
          return nil, err
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
  local self = _class_0
  self.type_err_message = "expecting table"
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
    on_repair = function(self, repair_fn)
      return Pattern(self.pattern, self:clone_opts({
        repair = repair_fn
      }))
    end,
    describe = function(self)
      return "pattern `" .. tostring(self.pattern) .. "`"
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
  any = AnyType,
  string = Type("string"),
  number = Type("number"),
  ["function"] = Type("function"),
  func = Type("function"),
  boolean = Type("boolean"),
  userdata = Type("userdata"),
  ["nil"] = Type("nil"),
  table = Type("table"),
  array = ArrayType(),
  integer = Pattern("^%d+$", {
    coerce = true,
    initial_type = "number"
  }),
  one_of = OneOf,
  shape = Shape,
  pattern = Pattern,
  array_of = ArrayOf,
  map_of = MapOf
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
  VERSION = "1.2.1"
}
