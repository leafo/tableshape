import BaseType, FailedTransform from require "tableshape"

-- plain boolean versions of the type checks below, closed over by the
-- tableshape.codegen protocol hooks (_compile_predicate). These must match
-- the pass/fail behavior of the corresponding _transform implementations
is_class = (value) ->
  return false unless type(value) == "table"
  return false if rawget(value, "__base") == nil

  mt = getmetatable value
  return false unless mt and rawget(mt, "__call") != nil

  true

is_instance = (value) ->
  return false unless type(value) == "table"

  mt = getmetatable value
  return false unless mt
  return false unless rawget(mt, "__index") == mt
  return false if rawget(value, "__index") == value
  return false if value.__index == value

  true

is_subclass_of = (value, class_identifier, allow_same) ->
  return false unless is_class value

  current_class = if allow_same
    value
  else
    value.__parent

  if type(class_identifier) == "string"
    while current_class
      return true if current_class.__name == class_identifier
      current_class = current_class.__parent
  else
    while current_class
      return true if current_class == class_identifier
      current_class = current_class.__parent

  false

is_instance_of = (value, class_identifier) ->
  return false unless is_instance value

  current_cls = value.__class

  if type(class_identifier) == "string"
    while current_cls
      return true if current_cls.__name == class_identifier
      current_cls = current_cls.__parent
  else
    while current_cls
      return true if current_cls == class_identifier
      current_cls = current_cls.__parent

  false

class ClassType extends BaseType
  _compile_pure: true
  _compile_predicate: (compiler, v, s) =>
    "#{compiler\ref is_class}(#{v})"

  _transform: (value, state) =>
    unless type(value) == "table"
      return FailedTransform, "expecting table"

    unless rawget(value, "__base") != nil
      return FailedTransform, "table is not class (missing __base)"

    mt = getmetatable value
    unless mt and rawget(mt, "__call") != nil
      return FailedTransform, "table is not class (missing constructor)"

    value, state

  _describe: =>
    "class"

class InstanceType extends BaseType
  _compile_pure: true
  _compile_predicate: (compiler, v, s) =>
    "#{compiler\ref is_instance}(#{v})"

  _transform: (value, state) =>
    unless type(value) == "table"
      return FailedTransform, "expecting table"

    mt = getmetatable value

    unless mt
      return FailedTransform, "table is not instance (missing metatable)"

    unless rawget(mt, "__index") == mt
      return FailedTransform, "table is not instance (metatable __index does not refer to metatable)"

    if rawget(value, "__index") == value
      return FailedTransform, "table is not instance (__base object, not instance)"

    if value.__index == value
      return FailedTransform, "table is an instance metatable (__base)"

    value, state

  _describe: =>
    "instance"


class SubclassOf extends BaseType
  _compile_pure: true
  _compile_predicate: (compiler, v, s) =>
    "#{compiler\ref is_subclass_of}(#{v}, #{compiler\value_expr @class_identifier}, #{tostring @allow_same})"

  new: (@class_identifier, opts) =>
    @allow_same = if opts and opts.allow_same
      true
    else
      false

    assert @class_identifier, "expecting class identifier (string or class object)"

  _transform: (value, state) =>
    out, err = ClassType._transform nil, value, state
    if out == FailedTransform
      return FailedTransform, err

    current_class = if @allow_same
      value
    else
      value.__parent

    if type(@class_identifier) == "string"
      while current_class
        if current_class.__name == @class_identifier
          return value, state

        current_class = current_class.__parent
    else
      while current_class
        if current_class == @class_identifier
          return value, state

        current_class = current_class.__parent

    FailedTransform, "table is not #{@_describe!}"

  _describe: =>
    name = if type(@class_identifier) == "string"
      @class_identifier
    else
      @class_identifier.__name or "Class"

    "subclass of #{name}"

class InstanceOf extends BaseType
  _compile_pure: true
  _compile_predicate: (compiler, v, s) =>
    "#{compiler\ref is_instance_of}(#{v}, #{compiler\value_expr @class_identifier})"

  new: (@class_identifier) =>
    assert @class_identifier, "expecting class identifier (string or class object)"

  _transform: (value, state) =>
    out, err = InstanceType._transform nil, value, state
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
  subclass_of: SubclassOf
}, __index: (fn_name) =>
  error "Type checker does not exist: `#{fn_name}`"
