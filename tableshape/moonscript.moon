import BaseType, FailedTransform from require "tableshape"

class ClassType extends BaseType
  _transform: (value, state) =>
    unless type(value) == "table"
      return FailedTransform, "expecting table"

    base = value.__base
    unless base
      return FailedTransform, "table is not class (missing __base)"

    unless type(base) == "table"
      return FailedTransform, "table is not class (__base not table)"

    mt = getmetatable value
    unless mt
      return FailedTransform, "table is not class (missing metatable)"

    unless mt.__call
      return FailedTransform, "table is not class (no constructor)"

    value, state

  _describe: =>
    "class"

class InstanceType extends BaseType
  _transform: (value, state) =>
    unless type(value) == "table"
      return FailedTransform, "expecting table"

    mt = getmetatable value

    unless mt
      return FailedTransform, "table is not instance (missing metatable)"

    cls = rawget mt, "__class"
    unless cls
      return FailedTransform, "table is not instance (metatable does not have __class)"

    value, state

  _describe: =>
    "instance"

class InstanceOf extends BaseType
  new: (@class_identifier) =>
    assert @class_identifier, "expecting class identifier (string or class object)"

  _transform: (value, state) =>
    out, err = InstanceType._transform @, value, state
    if out == FailedTransform
      return FailedTransform, err

    cls = value.__class

    if type(@class_identifier) == "string"
      current_cls = cls
      while current_cls
        if current_cls.__name == @class_identifier
          return value, state

        current_cls = current_cls.__parent
    else
      current_cls = cls
      while current_cls
        if current_cls == @class_identifier
          return value, state

        current_cls = current_cls.__parent

    FailedTransform, "table is not #{@_describe!}"

  _describe: =>
    name = if type(@class_identifier) == "string"
      @class_identifier
    else
      @class_identifier.__name or "Class"

    "instance of #{name}"

setmetatable {
  class_type: ClassType!
  instance_type: InstanceType!

  instance_of: InstanceOf
}, __index: (fn_name) =>
  error "Type checker does not exist: `#{fn_name}`"
