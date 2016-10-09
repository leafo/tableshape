local OptionalType
local BaseType
do
  local _class_0
  local _base_0 = {
    __eq = function(self, other)
      if BaseType:is_base_type(other) then
        print("other is base type")
        return other(self)
      else
        return self(other[1])
      end
    end,
    check_value = function(self)
      return error("override me")
    end,
    has_repair = function(self)
      return self.opts and self.opts.repair
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
    is_optional = function(self)
      return OptionalType(self)
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
    __init = function(self)
      if self.opts then
        self.describe = self.opts.describe
      end
    end,
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
    cls.__base.__eq = self.__eq
    local mt = getmetatable(cls)
    local create = mt.__call
    mt.__call = function(cls, ...)
      local ret = create(cls, ...)
      if ret.opts and ret.opts.optional then
        return ret:is_optional()
      else
        return ret
      end
    end
  end
  BaseType = _class_0
end
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    check_value = function(self, value)
      if value == nil then
        return true
      end
      return self.base_type:check_value(value)
    end,
    is_optional = function(self)
      return self
    end,
    on_repair = function(self, repair_fn)
      return OptionalType(self.base_type, self:clone_opts({
        repair = repair_fn
      }))
    end,
    repair = function(self, value, fix_fn)
      fix_fn = fix_fn or (self.opts and self.opts.repair)
      fix_fn = fix_fn or (function()
        local _base_1 = self.base_type
        local _fn_0 = _base_1.repair
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)()
      return _class_0.__parent.__base.repair(self, value, fix_fn)
    end,
    describe = function(self)
      if self.base_type.describe then
        local base_description = self.base_type:describe()
        return "optional " .. tostring(base_description)
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, base_type, opts)
      self.base_type, self.opts = base_type, opts
      _class_0.__parent.__init(self)
      assert(BaseType:is_base_type(base_type) and base_type.check_value, "expected a type checker")
      if (self.base_type.opts or { }).repair and not (self.opts or { }).repair then
        self.opts = self.opts or { }
        self.opts.repair = self.base_type.opts.repair
      end
    end,
    __base = _base_0,
    __name = "OptionalType",
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
  OptionalType = _class_0
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
    on_repair = function(self, repair_fn)
      return Type(self.t, self:clone_opts({
        repair = repair_fn
      }))
    end,
    check_value = function(self, value)
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
      return _class_0.__parent.__init(self)
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
    on_repair = function(self, repair_fn)
      return ArrayType(self:clone_opts({
        repair = repair_fn
      }))
    end,
    check_value = function(self, value)
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
      return _class_0.__parent.__init(self)
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
    on_repair = function(self, repair_fn)
      return OneOf(self.items, self:clone_opts({
        repair = repair_fn
      }))
    end,
    repair = function(self, value, fn)
      local _list_0 = self.items
      for _index_0 = 1, #_list_0 do
        local _continue_0 = false
        repeat
          local item = _list_0[_index_0]
          if value == item then
            return value, false
          end
          if not (BaseType:is_base_type(item) and item:has_repair()) then
            _continue_0 = true
            break
          end
          local res, fixed = item:repair(value)
          if fixed and item:check_value(res) then
            return res, fixed
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return _class_0.__parent.__base.repair(self, value, fn)
    end,
    describe = function(self)
      local item_names
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = self.items
        for _index_0 = 1, #_list_0 do
          local i = _list_0[_index_0]
          if type(i) == "table" and i.describe then
            _accum_0[_len_0] = i:describe()
          else
            _accum_0[_len_0] = "`" .. tostring(i) .. "`"
          end
          _len_0 = _len_0 + 1
        end
        item_names = _accum_0
      end
      return "one of: " .. tostring(table.concat(item_names, ", "))
    end,
    check_value = function(self, value)
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
      return nil, "value `" .. tostring(value) .. "` does not match " .. tostring(self:describe())
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, items, opts)
      self.items, self.opts = items, opts
      _class_0.__parent.__init(self)
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
local AllOf
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    on_repair = function(self, repair_fn)
      return AllOf(self.types, self:clone_opts({
        repair = repair_fn
      }))
    end,
    repair = function(self, val, repair_fn)
      local has_own_repair = self:has_repair() or repair_fn
      local repairs = 0
      local _list_0 = self.types
      for _index_0 = 1, #_list_0 do
        local _continue_0 = false
        repeat
          local t = _list_0[_index_0]
          if not (t:has_repair()) then
            _continue_0 = true
            break
          end
          repairs = repairs + 1
          local fixed
          val, fixed = t:repair(val)
          if fixed and not t:check_value(val) then
            return val, fixed
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      if repairs == 0 or self:has_repair() then
        return _class_0.__parent.__base.repair(self, val, repair_fn)
      else
        return val, true
      end
    end,
    check_value = function(self, value)
      local _list_0 = self.types
      for _index_0 = 1, #_list_0 do
        local t = _list_0[_index_0]
        local pass, err = t:check_value(value)
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
    __init = function(self, types, opts)
      self.types, self.opts = types, opts
      _class_0.__parent.__init(self)
      assert(type(self.types) == "table", "expected table for first argument")
      local _list_0 = self.types
      for _index_0 = 1, #_list_0 do
        local checker = _list_0[_index_0]
        assert(BaseType:is_base_type(checker), "all_of expects all type checkers")
      end
    end,
    __base = _base_0,
    __name = "AllOf",
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
  AllOf = _class_0
end
local ArrayOf
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    on_repair = function(self, repair_fn)
      return ArrayOf(self.expected, self:clone_opts({
        repair = repair_fn
      }))
    end,
    repair = function(self, tbl, fix_fn)
      if not (type(tbl) == "table") then
        fix_fn = fix_fn or (self.opts and self.opts.repair)
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
            fix_fn = fix_fn or (self.opts and self.opts.repair)
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
      return _class_0.__parent.__init(self)
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
    on_repair = function(self, repair_fn)
      return MapOf(self.expected_key, self.expected_value, self:clone_opts({
        repair = repair_fn
      }))
    end,
    check_value = function(self, value)
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
      return _class_0.__parent.__init(self)
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
        if not (fix_fn) then
          local keys
          do
            local _accum_0 = { }
            local _len_0 = 1
            for key in pairs(remaining_keys) do
              _accum_0[_len_0] = tostring(key)
              _len_0 = _len_0 + 1
            end
            keys = _accum_0
          end
          error("missing repair function for: extra fields (" .. tostring(table.concat(keys, ", ")) .. ")")
        end
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
          return nil, "field `" .. tostring(key) .. "`: " .. tostring(err), err
        end
      else
        local err = "expected `" .. tostring(expected_value) .. "`, got `" .. tostring(value) .. "`"
        return nil, "field `" .. tostring(key) .. "` " .. tostring(err), err
      end
      return true
    end,
    field_errors = function(self, value, short_circuit)
      if short_circuit == nil then
        short_circuit = false
      end
      if not (type(value) == "table") then
        if short_circuit then
          return self.__class.type_err_message
        else
          return {
            self.__class.type_err_message
          }
        end
      end
      local errors
      if not (short_circuit) then
        errors = { }
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
        local pass, err, standalone_err = self:check_field(shape_key, item_value, shape_val, value)
        if not (pass) then
          if short_circuit then
            return err
          else
            errors[shape_key] = standalone_err or err
            table.insert(errors, err)
          end
        end
      end
      if remaining_keys then
        do
          local extra_key = next(remaining_keys)
          if extra_key then
            local msg = "has extra field: `" .. tostring(extra_key) .. "`"
            if short_circuit then
              return msg
            else
              return {
                msg
              }
            end
          end
        end
      end
      return errors
    end,
    check_value = function(self, value)
      do
        local err = self:field_errors(value, true)
        if err then
          return nil, err
        else
          return true
        end
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, shape, opts)
      self.shape, self.opts = shape, opts
      _class_0.__parent.__init(self)
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
    on_repair = function(self, repair_fn)
      return Pattern(self.pattern, self:clone_opts({
        repair = repair_fn
      }))
    end,
    describe = function(self)
      return "pattern `" .. tostring(self.pattern) .. "`"
    end,
    check_value = function(self, value)
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
      return _class_0.__parent.__init(self)
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
local Literal
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    describe = function(self)
      return "literal `" .. tostring(self.value) .. "`"
    end,
    on_repair = function(self, repair_fn)
      return Literal(self.value, self:clone_opts({
        repair = repair_fn
      }))
    end,
    check_value = function(self, val)
      if self.value ~= val then
        return nil, "got `" .. tostring(val) .. "`, expected `" .. tostring(self.value) .. "`"
      end
      return true
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, value, opts)
      self.value, self.opts = value, opts
      return _class_0.__parent.__init(self)
    end,
    __base = _base_0,
    __name = "Literal",
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
  Literal = _class_0
end
local Custom
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    describe = function(self)
      return self.opts.describe or "custom checker " .. tostring(self.fn)
    end,
    on_repair = function(self, repair_fn)
      return Custom(self.fn, self:clone_opts({
        repair = repair_fn
      }))
    end,
    check_value = function(self, val)
      local pass, err = self.fn(val, self)
      if not (pass) then
        return nil, err or tostring(val) .. " is invalid"
      end
      return true
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, fn, opts)
      self.fn, self.opts = fn, opts
      return _class_0.__parent.__init(self)
    end,
    __base = _base_0,
    __name = "Custom",
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
  Custom = _class_0
end
local Equivalent
do
  local _class_0
  local values_equivalent
  local _parent_0 = BaseType
  local _base_0 = {
    on_repair = function(self)
      return Equivalent(self.val, self:clone_opts({
        repair = repair_fn
      }))
    end,
    check_value = function(self, val)
      if values_equivalent(self.val, val) then
        return true
      else
        return nil, tostring(val) .. " is not equivalent to " .. tostring(self.val)
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, val, opts)
      self.val, self.opts = val, opts
      return _class_0.__parent.__init(self)
    end,
    __base = _base_0,
    __name = "Equivalent",
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
  values_equivalent = function(a, b)
    if a == b then
      return true
    end
    if type(a) == "table" and type(b) == "table" then
      local seen_keys = { }
      for k, v in pairs(a) do
        seen_keys[k] = true
        if not (values_equivalent(v, b[k])) then
          return false
        end
      end
      for k, v in pairs(b) do
        local _continue_0 = false
        repeat
          if seen_keys[k] then
            _continue_0 = true
            break
          end
          if not (values_equivalent(v, a[k])) then
            return false
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return true
    else
      return false
    end
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Equivalent = _class_0
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
  all_of = AllOf,
  shape = Shape,
  pattern = Pattern,
  array_of = ArrayOf,
  map_of = MapOf,
  literal = Literal,
  equivalent = Equivalent,
  custom = Custom
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
local is_type
is_type = function(val)
  return BaseType:is_base_type(val)
end
local type_switch
type_switch = function(val)
  return setmetatable({
    val
  }, {
    __eq = BaseType.__eq
  })
end
return {
  check_shape = check_shape,
  types = types,
  is_type = is_type,
  type_switch = type_switch,
  BaseType = BaseType,
  VERSION = "1.2.1"
}
