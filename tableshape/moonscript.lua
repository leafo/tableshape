local BaseType, FailedTransform
do
  local _obj_0 = require("tableshape")
  BaseType, FailedTransform = _obj_0.BaseType, _obj_0.FailedTransform
end
local ClassType
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    _transform = function(self, value, state)
      if not (type(value) == "table") then
        return FailedTransform, "expecting table"
      end
      local base = value.__base
      if not (base) then
        return FailedTransform, "table is not class (missing __base)"
      end
      if not (type(base) == "table") then
        return FailedTransform, "table is not class (__base not table)"
      end
      local mt = getmetatable(value)
      if not (mt) then
        return FailedTransform, "table is not class (missing metatable)"
      end
      if not (mt.__call) then
        return FailedTransform, "table is not class (no constructor)"
      end
      return value, state
    end,
    _describe = function(self)
      return "class"
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "ClassType",
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
  ClassType = _class_0
end
local InstanceType
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    _transform = function(self, value, state)
      if not (type(value) == "table") then
        return FailedTransform, "expecting table"
      end
      local mt = getmetatable(value)
      if not (mt) then
        return FailedTransform, "table is not instance (missing metatable)"
      end
      local cls = rawget(mt, "__class")
      if not (cls) then
        return FailedTransform, "table is not instance (metatable does not have __class)"
      end
      return value, state
    end,
    _describe = function(self)
      return "instance"
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "InstanceType",
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
  InstanceType = _class_0
end
local InstanceOf
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    _transform = function(self, value, state)
      local out, err = InstanceType._transform(self, value, state)
      if out == FailedTransform then
        return FailedTransform, err
      end
      local cls = value.__class
      if type(self.class_identifier) == "string" then
        local current_cls = cls
        while current_cls do
          if current_cls.__name == self.class_identifier then
            return value, state
          end
          current_cls = current_cls.__parent
        end
      else
        local current_cls = cls
        while current_cls do
          if current_cls == self.class_identifier then
            return value, state
          end
          current_cls = current_cls.__parent
        end
      end
      return FailedTransform, "table is not " .. tostring(self:_describe())
    end,
    _describe = function(self)
      local name
      if type(self.class_identifier) == "string" then
        name = self.class_identifier
      else
        name = self.class_identifier.__name or "Class"
      end
      return "instance of " .. tostring(name)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, class_identifier)
      self.class_identifier = class_identifier
      return assert(self.class_identifier, "expecting class identifier (string or class object)")
    end,
    __base = _base_0,
    __name = "InstanceOf",
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
  InstanceOf = _class_0
end
return setmetatable({
  class_type = ClassType(),
  instance_type = InstanceType(),
  instance_of = InstanceOf
}, {
  __index = function(self, fn_name)
    return error("Type checker does not exist: `" .. tostring(fn_name) .. "`")
  end
})
