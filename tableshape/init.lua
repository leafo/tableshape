local OptionalType, TaggedType, types
local TagValueArray = { }
local FailedTransform = { }
local unpack = unpack or table.unpack
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
local BaseType, TransformNode, SequenceNode, FirstOfNode, DescribeNode
local describe_literal
describe_literal = function(val)
  local _exp_0 = type(val)
  if "string" == _exp_0 then
    if not val:match('"') then
      return "\"" .. tostring(val) .. "\""
    elseif not val:match("'") then
      return "'" .. tostring(val) .. "'"
    else
      return "`" .. tostring(val) .. "`"
    end
  else
    if BaseType:is_base_type(val) then
      return val:_describe()
    else
      return tostring(val)
    end
  end
end
local join_names
join_names = function(items, sep, last_sep)
  if sep == nil then
    sep = ", "
  end
  local count = #items
  local chunks = { }
  for idx, name in ipairs(items) do
    if idx > 1 then
      local current_sep
      if idx == count then
        current_sep = last_sep or sep
      else
        current_sep = sep
      end
      table.insert(chunks, current_sep)
    end
    table.insert(chunks, name)
  end
  return table.concat(chunks)
end
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
    _describe = function(self)
      return error("Node missing _describe: " .. tostring(self.__class.__name))
    end,
    check_value = function(self, ...)
      local value, state_or_err = self:_transform(...)
      if value == FailedTransform then
        return nil, state_or_err
      end
      if type(state_or_err) == "table" then
        return state_or_err
      else
        return true
      end
    end,
    transform = function(self, ...)
      local value, state_or_err = self:_transform(...)
      if value == FailedTransform then
        return nil, state_or_err
      end
      if type(state_or_err) == "table" then
        return value, state_or_err
      else
        return value
      end
    end,
    repair = function(self, ...)
      return self:transform(...)
    end,
    on_repair = function(self, fn)
      return (self + types.any / fn * self):describe(function()
        return self:_describe()
      end)
    end,
    is_optional = function(self)
      return OptionalType(self)
    end,
    describe = function(self, ...)
      return DescribeNode(self, ...)
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
        self._describe = self.opts.describe
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
    _describe = function(self)
      return self.node:_describe()
    end,
    _transform = function(self, value, state)
      local state_or_err
      value, state_or_err = self.node:_transform(value, state)
      if value == FailedTransform then
        return FailedTransform, state_or_err
      else
        local out
        local _exp_0 = type(self.t_fn)
        if "function" == _exp_0 then
          out = self.t_fn(value)
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
      return assert(self.node, "missing node for transform")
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
    _describe = function(self)
      local item_names
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = self.sequence
        for _index_0 = 1, #_list_0 do
          local i = _list_0[_index_0]
          if type(i) == "table" and i._describe then
            _accum_0[_len_0] = i:_describe()
          else
            _accum_0[_len_0] = describe_literal(i)
          end
          _len_0 = _len_0 + 1
        end
        item_names = _accum_0
      end
      return join_names(item_names, " then ")
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
    _describe = function(self)
      local item_names
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = self.options
        for _index_0 = 1, #_list_0 do
          local i = _list_0[_index_0]
          if type(i) == "table" and i._describe then
            _accum_0[_len_0] = i:_describe()
          else
            _accum_0[_len_0] = describe_literal(i)
          end
          _len_0 = _len_0 + 1
        end
        item_names = _accum_0
      end
      return join_names(item_names, ", ", ", or ")
    end,
    _transform = function(self, value, state)
      if not (self.options[1]) then
        return FailedTransform, "no options for node"
      end
      local _list_0 = self.options
      for _index_0 = 1, #_list_0 do
        local node = _list_0[_index_0]
        local new_val, new_state_or_err = node:_transform(value, state)
        if not (new_val == FailedTransform) then
          return new_val, new_state_or_err
        end
      end
      return FailedTransform, "expected " .. tostring(self:_describe())
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
    _transform = function(self, input, ...)
      local value, state = self.node:_transform(input, ...)
      if value == FailedTransform then
        return FailedTransform, "expected " .. tostring(self:_describe(input, ...))
      end
      return value, state
    end,
    describe = function(self, ...)
      return DescribeNode(self.node, ...)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, node, describe)
      self.node = node
      if type(describe) == "string" then
        self._describe = function()
          return describe
        end
      else
        self._describe = describe
      end
    end,
    __base = _base_0,
    __name = "DescribeNode",
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
  DescribeNode = _class_0
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
    _describe = function(self)
      local base_description = self.base_type:_describe()
      return tostring(base_description) .. " tagged " .. tostring(describe_literal(self.tag))
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
    _transform = function(self, value, state)
      if value == nil then
        return value, state
      end
      return self.base_type:_transform(value, state)
    end,
    is_optional = function(self)
      return self
    end,
    _describe = function(self)
      if self.base_type._describe then
        local base_description = self.base_type:_describe()
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
    _transform = function(self, v, state)
      return v, state
    end,
    _describe = function(self)
      return "anything"
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
    _transform = function(self, value, state)
      local got = type(value)
      if self.t ~= got then
        return FailedTransform, "expected type " .. tostring(describe_literal(self.t)) .. ", got " .. tostring(describe_literal(got))
      end
      if self.length_type then
        local len = #value
        local res
        res, state = self.length_type:_transform(len, state)
        if res == FailedTransform then
          return FailedTransform, tostring(self.t) .. " length " .. tostring(state) .. ", got " .. tostring(len)
        end
      end
      return value, state
    end,
    length = function(self, left, right)
      local l
      if BaseType:is_base_type(left) then
        l = left
      else
        l = types.range(left, right)
      end
      return Type(self.t, self:clone_opts({
        length = l
      }))
    end,
    _describe = function(self)
      local t = "type " .. tostring(describe_literal(self.t))
      if self.length_type then
        t = t .. " length_type " .. tostring(self.length_type:_describe())
      end
      return t
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, t, opts)
      self.t, self.opts = t, opts
      if self.opts then
        self.length_type = self.opts.length
      end
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
    _describe = function(self)
      return "an array"
    end,
    _transform = function(self, value, state)
      if not (type(value) == "table") then
        return FailedTransform, "expecting table"
      end
      local k = 1
      for i, v in pairs(value) do
        if not (type(i) == "number") then
          return FailedTransform, "non number field: " .. tostring(i)
        end
        if not (i == k) then
          return FailedTransform, "non array index, got " .. tostring(describe_literal(i)) .. " but expected " .. tostring(describe_literal(k))
        end
        k = k + 1
      end
      return value, state
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
    _describe = function(self)
      local item_names
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = self.options
        for _index_0 = 1, #_list_0 do
          local i = _list_0[_index_0]
          if type(i) == "table" and i._describe then
            _accum_0[_len_0] = i:_describe()
          else
            _accum_0[_len_0] = describe_literal(i)
          end
          _len_0 = _len_0 + 1
        end
        item_names = _accum_0
      end
      return tostring(join_names(item_names, ", ", ", or "))
    end,
    _transform = function(self, value, state)
      if self.options_hash then
        if self.options_hash[value] then
          return value, state
        end
      else
        local _list_0 = self.options
        for _index_0 = 1, #_list_0 do
          local _continue_0 = false
          repeat
            local item = _list_0[_index_0]
            if item == value then
              return value, state
            end
            if BaseType:is_base_type(item) then
              local new_value, new_state = item:_transform(value, state)
              if new_value == FailedTransform then
                _continue_0 = true
                break
              end
              return new_value, new_state
            end
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
      end
      return FailedTransform, "expected " .. tostring(self:_describe())
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, options, opts)
      self.options, self.opts = options, opts
      _class_0.__parent.__init(self)
      assert(type(self.options) == "table", "expected table for options in one_of")
      local fast_opts = types.array_of(types.number + types.string)
      if fast_opts(self.options) then
        do
          local _tbl_0 = { }
          local _list_0 = self.options
          for _index_0 = 1, #_list_0 do
            local v = _list_0[_index_0]
            _tbl_0[v] = true
          end
          self.options_hash = _tbl_0
        end
      end
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
    _transform = function(self, value, state)
      local new_state
      local _list_0 = self.types
      for _index_0 = 1, #_list_0 do
        local t = _list_0[_index_0]
        value, new_state = t:_transform(value, new_state)
        if value == FailedTransform then
          return FailedTransform, new_state
        end
      end
      return value, merge_tag_state(state, new_state)
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
    _describe = function(self)
      return "array of " .. tostring(describe_literal(self.expected))
    end,
    _transform = function(self, value, state)
      local pass, err = types.table(value)
      if not (pass) then
        return FailedTransform, err
      end
      if self.length_type then
        local len = #value
        local res
        res, state = self.length_type:_transform(len, state)
        if res == FailedTransform then
          return FailedTransform, "array length " .. tostring(state) .. ", got " .. tostring(len)
        end
      end
      local is_literal = not BaseType:is_base_type(self.expected)
      local new_state
      local out
      do
        local _accum_0 = { }
        local _len_0 = 1
        for idx, item in ipairs(value) do
          local _continue_0 = false
          repeat
            if is_literal then
              if self.expected ~= item then
                return FailedTransform, "array item " .. tostring(idx) .. ": expected " .. tostring(describe_literal(self.expected))
              else
                _accum_0[_len_0] = item
              end
            else
              local item_val
              item_val, new_state = self.expected:_transform(item, new_state)
              if item_val == FailedTransform then
                return FailedTransform, "array item " .. tostring(idx) .. ": " .. tostring(new_state)
              end
              if item_val == nil and not self.keep_nils then
                _continue_0 = true
                break
              end
              _accum_0[_len_0] = item_val
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
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, expected, opts)
      self.expected, self.opts = expected, opts
      if self.opts then
        self.keep_nils = self.opts.keep_nils
        self.length_type = self.opts.length
      end
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
              return FailedTransform, "map key expected " .. tostring(describe_literal(self.expected_key))
            end
          else
            k, new_state = self.expected_key:_transform(k, new_state)
            if k == FailedTransform then
              return FailedTransform, "map key " .. tostring(new_state)
            end
          end
          if value_literal then
            if v ~= self.expected_value then
              return FailedTransform, "map value expected " .. tostring(describe_literal(self.expected_value))
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
      local check_all = self.check_all
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
        local new_val, tuple_state
        if BaseType:is_base_type(shape_val) then
          new_val, tuple_state = shape_val:_transform(item_value, new_state)
        else
          if shape_val == item_value then
            new_val, tuple_state = item_value, new_state
          else
            new_val, tuple_state = FailedTransform, "expected " .. tostring(describe_literal(item_value))
          end
        end
        if new_val == FailedTransform then
          err = "field " .. tostring(describe_literal(shape_key)) .. ": " .. tostring(tuple_state)
          if check_all then
            if errors then
              table.insert(errors, err)
            else
              errors = {
                err
              }
            end
          else
            return FailedTransform, err
          end
        else
          new_state = tuple_state
          out[shape_key] = new_val
        end
      end
      if remaining_keys and next(remaining_keys) then
        if self.open then
          for k in pairs(remaining_keys) do
            out[k] = value[k]
          end
        elseif self.extra_fields_type then
          for k in pairs(remaining_keys) do
            local tuple, tuple_state = self.extra_fields_type:_transform({
              [k] = value[k]
            }, new_state)
            if tuple == FailedTransform then
              err = "field " .. tostring(describe_literal(k)) .. ": " .. tostring(tuple_state)
              if check_all then
                if errors then
                  table.insert(errors, err)
                else
                  errors = {
                    err
                  }
                end
              else
                return FailedTransform, err
              end
            else
              new_state = tuple_state
              do
                local nk = tuple and next(tuple)
                if nk then
                  out[nk] = tuple[nk]
                end
              end
            end
          end
        else
          local names
          do
            local _accum_0 = { }
            local _len_0 = 1
            for key in pairs(remaining_keys) do
              _accum_0[_len_0] = describe_literal(key)
              _len_0 = _len_0 + 1
            end
            names = _accum_0
          end
          err = "extra fields: " .. tostring(table.concat(names, ", "))
          if check_all then
            if errors then
              table.insert(errors, err)
            else
              errors = {
                err
              }
            end
          else
            return FailedTransform, err
          end
        end
      end
      if errors and next(errors) then
        return FailedTransform, table.concat(errors, "; ")
      end
      return out, merge_tag_state(state, new_state)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, shape, opts)
      self.shape, self.opts = shape, opts
      _class_0.__parent.__init(self)
      assert(type(self.shape) == "table", "expected table for shape")
      if self.opts then
        self.extra_fields_type = self.opts.extra_fields
        self.open = self.opts.open
        self.check_all = self.opts.check_all
        if self.open then
          assert(not self.extra_fields_type, "open can not be combined with extra_fields")
        end
        if self.extra_fields_type then
          return assert(not self.open, "extra_fields can not be combined with open")
        end
      end
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
    _describe = function(self)
      return "pattern " .. tostring(describe_literal(self.pattern))
    end,
    _transform = function(self, value, state)
      do
        local initial = self.opts and self.opts.initial_type
        if initial then
          if not (type(value) == initial) then
            return FailedTransform, "expected " .. tostring(describe_literal(initial))
          end
        end
      end
      if self.opts and self.opts.coerce then
        value = tostring(value)
      end
      local t_res, err = types.string(value)
      if not (t_res) then
        return FailedTransform, err
      end
      if value:match(self.pattern) then
        return value, state
      else
        return FailedTransform, "doesn't match " .. tostring(self:_describe())
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
    _describe = function(self)
      return describe_literal(self.value)
    end,
    _transform = function(self, value, state)
      if self.value ~= value then
        return FailedTransform, "expected " .. tostring(self:_describe())
      end
      return value, state
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
    _describe = function(self)
      return self.opts and self.opts.describe or "custom checker " .. tostring(self.fn)
    end,
    _transform = function(self, value, state)
      local pass, err = self.fn(value, self)
      if not (pass) then
        return FailedTransform, err or "failed custom check"
      end
      return value, state
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
    _transform = function(self, value, state)
      if values_equivalent(self.val, value) then
        return value, state
      else
        return FailedTransform, "not equivalent to " .. tostring(self.val)
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
local Range
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    _transform = function(self, value, state)
      local res
      res, state = self.value_type:_transform(value, state)
      if res == FailedTransform then
        return FailedTransform, "range " .. tostring(state)
      end
      if value < self.left then
        return FailedTransform, "not in " .. tostring(self:_describe())
      end
      if value > self.right then
        return FailedTransform, "not in " .. tostring(self:_describe())
      end
      return value, state
    end,
    _describe = function(self)
      return "range from " .. tostring(self.left) .. " to " .. tostring(self.right)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, left, right, opts)
      self.left, self.right, self.opts = left, right, opts
      _class_0.__parent.__init(self)
      assert(self.left <= self.right, "left range value should be less than right range value")
      self.value_type = assert(types[type(self.left)], "couldn't figure out type of range boundary")
    end,
    __base = _base_0,
    __name = "Range",
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
  Range = _class_0
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
  range = Range,
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
