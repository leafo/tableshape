local OptionalType, TaggedType, types
local TagValueArray = { }
local FailedTransform = { }
local merge_tag_state
merge_tag_state = function(existing, new_tags)
  if type(new_tags) == "table" and type(existing) == "table" then
    for k, v in pairs(new_tags) do
      local ev = existing[k]
      if ev and getmetatable(ev) == TagValueArray and getmetatable(v) == TagValueArray then
        for _index_0 = 1, #v do
          local array_val = v[_index_0]
          table.insert(ev, array_val)
        end
      else
        existing[k] = v
      end
    end
    return existing
  end
  return new_tags or existing or true
end
local TransformNode, SequenceNode, FirstOfNode
local BaseType
do
  local _class_0
  local _base_0 = {
    __eq = function(self, other)
      if BaseType:is_base_type(other) then
        return other(self)
      else
        return self(other[1])
      end
    end,
    __div = function(self, fn)
      return TransformNode(self, fn)
    end,
    __mul = function(self, right)
      return SequenceNode(self, right)
    end,
    __add = function(self, right)
      if self.__class == FirstOfNode then
        local options = {
          unpack(self.options)
        }
        table.insert(options, right)
        return FirstOfNode(unpack(options))
      else
        return FirstOfNode(self, right)
      end
    end,
    check_value = function(self)
      return error("override me")
    end,
    transform = function(self, ...)
      local val, state_or_err = self:_transform(...)
      if val == FailedTransform then
        return nil, state_or_err
      end
      if type(state_or_err) == "table" then
        return val, state_or_err
      else
        return val
      end
    end,
    repair = function(self, ...)
      return self:transform(...)
    end,
    _transform = function(self, val, state)
      local err
      state, err = self:check_value(val, state)
      if state then
        return val, state
      else
        return FailedTransform, err
      end
    end,
    on_repair = function(self, fn)
      return self + types.any / fn * self
    end,
    is_optional = function(self)
      return OptionalType(self)
    end,
    tag = function(self, name)
      return TaggedType(self, {
        tag = name
      })
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
    cls.__base.__div = self.__div
    cls.__base.__mul = self.__mul
    cls.__base.__add = self.__add
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
    check_value = function(self, value, state)
      return self.node:check_value(value, state)
    end,
    _transform = function(self, value, state)
      local val, state_or_err = self.node:_transform(value, state)
      if val == FailedTransform then
        return val, state_or_err
      else
        local out
        local _exp_0 = type(self.t_fn)
        if "function" == _exp_0 then
          out = self.t_fn(val)
        else
          out = self.t_fn
        end
        return out, state_or_err
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, node, t_fn)
      self.node, self.t_fn = node, t_fn
    end,
    __base = _base_0,
    __name = "TransformNode",
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
  self.transformer = true
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  TransformNode = _class_0
end
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    check_value = function(self, value, state)
      local new_state
      local _list_0 = self.sequence
      for _index_0 = 1, #_list_0 do
        local node = _list_0[_index_0]
        local pass
        pass, new_state = node:check_value(value, new_state)
        if not (pass) then
          return nil, new_state
        end
      end
      return merge_tag_state(state, new_state)
    end,
    _transform = function(self, value, state)
      local _list_0 = self.sequence
      for _index_0 = 1, #_list_0 do
        local node = _list_0[_index_0]
        value, state = node:_transform(value, state)
        if value == FailedTransform then
          break
        end
      end
      return value, state
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      self.sequence = {
        ...
      }
    end,
    __base = _base_0,
    __name = "SequenceNode",
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
  self.transformer = true
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  SequenceNode = _class_0
end
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    check_value = function(self, value, state)
      local errors
      local _list_0 = self.options
      for _index_0 = 1, #_list_0 do
        local node = _list_0[_index_0]
        local pass, new_state_or_err = node:check_value(value)
        if pass then
          return merge_tag_state(state, new_state_or_err)
        else
          if errors then
            table.insert(errors, new_state_or_err)
          else
            errors = {
              new_state_or_err
            }
          end
        end
      end
      return nil, "no matching option (" .. tostring(table.concat(errors or {
        "no options"
      }, "; ")) .. ")"
    end,
    _transform = function(self, value, state)
      local errors
      if not (self.options[1]) then
        return FailedTransform, "no options for node"
      end
      local _list_0 = self.options
      for _index_0 = 1, #_list_0 do
        local node = _list_0[_index_0]
        local new_val, new_state_or_err = node:_transform(value, state)
        if new_val == FailedTransform then
          if errors then
            table.insert(errors, new_state_or_err)
          else
            errors = {
              new_state_or_err
            }
          end
        else
          return new_val, new_state_or_err
        end
      end
      return FailedTransform, "no matching option (" .. tostring(table.concat(errors or {
        "no options"
      }, "; ")) .. ")"
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      self.options = {
        ...
      }
    end,
    __base = _base_0,
    __name = "FirstOfNode",
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
  self.transformer = true
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  FirstOfNode = _class_0
end
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    _transform = function(self, value, state)
      value, state = self.base_type:_transform(value, state)
      if value == FailedTransform then
        return FailedTransform, state
      end
      if not (type(state) == "table") then
        state = { }
      end
      if self.array then
        local existing = state[self.tag]
        if type(existing) == "table" then
          table.insert(existing, value)
        else
          state[self.tag] = setmetatable({
            value
          }, TagValueArray)
        end
      else
        state[self.tag] = value
      end
      return value, state
    end,
    check_value = function(self, value, state)
      state = self.base_type:check_value(value, state)
      if state then
        if not (type(state) == "table") then
          state = { }
        end
        if self.array then
          local existing = state[self.tag]
          if type(existing) == "table" then
            table.insert(existing, value)
          else
            state[self.tag] = setmetatable({
              value
            }, TagValueArray)
          end
        else
          state[self.tag] = value
        end
        return state
      end
    end,
    describe = function(self)
      if self.base_type.describe then
        local base_description = self.base_type:describe()
        return tostring(base_description) .. " tagged `" .. tostring(self.tag) .. "`"
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, base_type, opts)
      self.base_type = base_type
      self.tag = assert(opts.tag, "tagged type missing tag")
      if self.tag:match("%[%]$") then
        self.tag = self.tag:sub(1, -3)
        self.array = true
      end
    end,
    __base = _base_0,
    __name = "TaggedType",
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
  TaggedType = _class_0
end
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    check_value = function(self, value, state)
      if value == nil then
        return state or true
      end
      return self.base_type:check_value(value, state)
    end,
    is_optional = function(self)
      return self
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
      return assert(BaseType:is_base_type(base_type), "expected a type checker")
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
    check_value = function(self, v, state)
      return state or true
    end,
    is_optional = function(self)
      return self
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
    check_value = function(self, value, state)
      local got = type(value)
      if self.t ~= got then
        return nil, "got type `" .. tostring(got) .. "`, expected `" .. tostring(self.t) .. "`"
      end
      return state or true
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
    check_value = function(self, value, state)
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
      return state or true
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
    check_value = function(self, value, state)
      local _list_0 = self.items
      for _index_0 = 1, #_list_0 do
        local item = _list_0[_index_0]
        if item == value then
          return state or true
        end
        if BaseType:is_base_type(item) and item.check_value then
          local new_state = item:check_value(value)
          if new_state then
            return merge_tag_state(state, new_state)
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
    check_value = function(self, value, state)
      local new_state = nil
      local _list_0 = self.types
      for _index_0 = 1, #_list_0 do
        local t = _list_0[_index_0]
        local err
        new_state, err = t:check_value(value, new_state)
        if not (new_state) then
          return nil, err
        end
      end
      return merge_tag_state(state, new_state)
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
    _transform = function(self, value, state)
      local pass, err = types.table(value)
      if not (pass) then
        return FailedTransform, err
      end
      local is_literal = not BaseType:is_base_type(self.expected)
      local new_state
      local out = { }
      do
        local _accum_0 = { }
        local _len_0 = 1
        for idx, item in ipairs(value) do
          local _continue_0 = false
          repeat
            if is_literal then
              if self.expected ~= item then
                return FailedTransform, "array item " .. tostring(idx) .. ": got `" .. tostring(item) .. "`, expected `" .. tostring(self.expected) .. "`"
              else
                _accum_0[_len_0] = item
              end
            else
              local val
              val, new_state = self.expected:_transform(item, new_state)
              if val == FailedTransform then
                return FailedTransform, "array item " .. tostring(idx) .. ": " .. tostring(new_state)
              end
              if val == nil and not self.keep_nils then
                _continue_0 = true
                break
              end
              _accum_0[_len_0] = val
            end
            _len_0 = _len_0 + 1
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        out = _accum_0
      end
      return out, merge_tag_state(state, new_state)
    end,
    check_field = function(self, key, value, tbl, state)
      if value == self.expected then
        return state or true
      end
      if BaseType:is_base_type(self.expected) then
        local err
        state, err = self.expected:check_value(value, state)
        if not (state) then
          return nil, "item " .. tostring(key) .. " in array does not match: " .. tostring(err)
        end
      else
        return nil, "item " .. tostring(key) .. " in array does not match `" .. tostring(self.expected) .. "`"
      end
      return state or true
    end,
    check_value = function(self, value, state)
      if not (type(value) == "table") then
        return nil, "expected table for array_of"
      end
      local new_state
      for idx, item in ipairs(value) do
        local err
        new_state, err = self:check_field(idx, item, value, new_state)
        if not (new_state) then
          return nil, err
        end
      end
      return merge_tag_state(state, new_state)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, expected, opts)
      self.expected, self.opts = expected, opts
      self.keep_nils = self.opts and self.opts.keep_nils
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
    _transform = function(self, value, state)
      local pass, err = types.table(value)
      if not (pass) then
        return FailedTransform, err
      end
      local new_state
      local key_literal = not BaseType:is_base_type(self.expected_key)
      local value_literal = not BaseType:is_base_type(self.expected_value)
      local out = { }
      for k, v in pairs(value) do
        local _continue_0 = false
        repeat
          if key_literal then
            if k ~= self.expected_key then
              return FailedTransform, "map key got `" .. tostring(k) .. "`, expected `" .. tostring(self.expected_key) .. "`"
            end
          else
            k, new_state = self.expected_key:_transform(k, new_state)
            if k == FailedTransform then
              return FailedTransform, "map key " .. tostring(new_state)
            end
          end
          if value_literal then
            if v ~= self.expected_value then
              return FailedTransform, "map value got `" .. tostring(v) .. "`, expected `" .. tostring(self.expected_value) .. "`"
            end
          else
            v, new_state = self.expected_value:_transform(v, new_state)
            if v == FailedTransform then
              return FailedTransform, "map value " .. tostring(new_state)
            end
          end
          if k == nil then
            _continue_0 = true
            break
          end
          out[k] = v
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return out, merge_tag_state(state, new_state)
    end,
    check_value = function(self, value, state)
      if not (type(value) == "table") then
        return nil, "expected table for map_of"
      end
      local new_state
      for k, v in pairs(value) do
        if self.expected_key.check_value then
          local err
          new_state, err = self.expected_key:check_value(k, new_state)
          if not (new_state) then
            return nil, "field `" .. tostring(k) .. "` in table does not match: " .. tostring(err)
          end
        else
          if not (self.expected_key == k) then
            return nil, "field `" .. tostring(k) .. "` does not match `" .. tostring(self.expected_key) .. "`"
          end
        end
        if self.expected_value.check_value then
          local err
          new_state, err = self.expected_value:check_value(v, new_state)
          if not (new_state) then
            return nil, "field `" .. tostring(k) .. "` value in table does not match: " .. tostring(err)
          end
        else
          if not (self.expected_value == v) then
            return nil, "field `" .. tostring(k) .. "` value does not match `" .. tostring(self.expected_value) .. "`"
          end
        end
      end
      return merge_tag_state(state, new_state)
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
    is_open = function(self)
      return Shape(self.shape, self:clone_opts({
        open = true
      }))
    end,
    _transform = function(self, value, state)
      local pass, err = types.table(value)
      if not (pass) then
        return FailedTransform, err
      end
      local remaining_keys
      do
        local _tbl_0 = { }
        for key in pairs(value) do
          _tbl_0[key] = true
        end
        remaining_keys = _tbl_0
      end
      local errors
      local out = { }
      local new_state
      for shape_key, shape_val in pairs(self.shape) do
        local item_value = value[shape_key]
        if remaining_keys then
          remaining_keys[shape_key] = nil
        end
        local new_val, tuple_state = shape_val:_transform(item_value, new_state)
        if new_val == FailedTransform then
          if not (errors) then
            errors = { }
          end
          table.insert(errors, "field `" .. tostring(shape_key) .. "`: " .. tostring(tuple_state))
        else
          new_state = merge_tag_state(new_state, tuple_state)
          out[shape_key] = new_val
        end
      end
      if remaining_keys and next(remaining_keys) then
        if self.opts and self.opts.open then
          for k in pairs(remaining_keys) do
            out[k] = value[k]
          end
        else
          local names
          do
            local _accum_0 = { }
            local _len_0 = 1
            for key in pairs(remaining_keys) do
              _accum_0[_len_0] = "`" .. tostring(key) .. "`"
              _len_0 = _len_0 + 1
            end
            names = _accum_0
          end
          if not (errors) then
            errors = { }
          end
          table.insert(errors, "extra fields: " .. tostring(table.concat(names, ", ")))
        end
      end
      if errors and next(errors) then
        return FailedTransform, table.concat(errors, "; ")
      end
      return out, merge_tag_state(state, new_state)
    end,
    check_field = function(self, key, value, expected_value, tbl, state)
      if value == expected_value then
        return state or true
      end
      if BaseType:is_base_type(expected_value) and expected_value.check_value then
        local err
        state, err = expected_value:check_value(value, state)
        if not (state) then
          return nil, "field `" .. tostring(key) .. "`: " .. tostring(err), err
        end
      else
        local err = "expected `" .. tostring(expected_value) .. "`, got `" .. tostring(value) .. "`"
        return nil, "field `" .. tostring(key) .. "` " .. tostring(err), err
      end
      return state or true
    end,
    check_fields = function(self, value, short_circuit)
      if short_circuit == nil then
        short_circuit = false
      end
      if not (type(value) == "table") then
        if short_circuit then
          return nil, self.__class.type_err_message
        else
          return nil, {
            self.__class.type_err_message
          }
        end
      end
      local errors
      if not (short_circuit) then
        errors = { }
      end
      local state = nil
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
        local err, standalone_err
        state, err, standalone_err = self:check_field(shape_key, item_value, shape_val, value, state)
        if not (state) then
          if short_circuit then
            return nil, err
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
              return nil, msg
            else
              return nil, {
                msg
              }
            end
          end
        end
      end
      if errors then
        return nil, errors
      end
      return state or true
    end,
    check_value = function(self, value, state)
      local new_state, err = self:check_fields(value, true)
      if new_state then
        return merge_tag_state(state, new_state)
      else
        return nil, err
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
    describe = function(self)
      return "pattern `" .. tostring(self.pattern) .. "`"
    end,
    check_value = function(self, value, state)
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
        return state or true
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
    check_value = function(self, val, state)
      if self.value ~= val then
        return nil, "got `" .. tostring(val) .. "`, expected `" .. tostring(self.value) .. "`"
      end
      return state or true
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
    check_value = function(self, val, state)
      local pass, err = self.fn(val, self)
      if not (pass) then
        return nil, err or tostring(val) .. " is invalid"
      end
      return state or true
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
    check_value = function(self, val, state)
      if values_equivalent(self.val, val) then
        return state or true
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
types = setmetatable({
  any = AnyType(),
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
