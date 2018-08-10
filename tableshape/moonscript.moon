import BaseType, FailedTransform from require "tableshape"

class InstanceOf extends BaseType
  new: (@class_identifier) =>
    assert @class_identifier, "expecting class identifier (string or class object)"

  _transform: (value, state) =>
    unless type(value) == "table"
      return FailedTransform, "expecting table"

    cls = value.__class
    unless cls
      return FailedTransform, "table does not have __class"

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
  instance_of: InstanceOf
}, __index: (fn_name) =>
  error "Type checker does not exist: `#{fn_name}`"
