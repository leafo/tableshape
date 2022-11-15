local OptionalType, TaggedType, types, is_type
local BaseType, TransformNode, SequenceNode, FirstOfNode, DescribeNode, NotType, Literal

-- Naming convention
-- Type: Something that checks the type/shape of something
-- Node: Something that adds additional information or does an operation on existing type(s)

-- unique object to identify failure case for return value from _transform
FailedTransform = {}

unpack = unpack or table.unpack

-- make a clone of state for insertion
clone_state = (state_obj) ->
  -- uninitialized state
  if type(state_obj) != "table"
    return {}

  -- shallow copy
  out = {k, v for k, v in pairs state_obj}
  if mt = getmetatable state_obj
    setmetatable out, mt

  out

-- Either use the describe method of the type, or print the literal value
describe_type = (val) ->
  if type(val) == "string"
    if not val\match '"'
      "\"#{val}\""
    elseif not val\match "'"
      "'#{val}'"
    else
      "`#{val}`"
  elseif BaseType\is_base_type val
    val\_describe!
  else
    tostring val

coerce_literal = (value) ->
  switch type value
    when "string", "number", "boolean"
      return Literal value
    when "table"
      -- already is a type
      if BaseType\is_base_type value
        return value

  nil, "failed to coerce literal into type, use types.literal() to test for literal value"

join_names = (items, sep=", ", last_sep) ->
  count = #items
  chunks = {}
  for idx, name in ipairs items
    if idx > 1
      current_sep = if idx == count
        last_sep or sep
      else
        sep
      table.insert chunks, current_sep

    table.insert chunks, name

  table.concat chunks


-- This is the base class that all types must inherit from.
-- Implementing types must provide the following methods:
-- _transform(value, state): => value, state
--   Transform the value and state. No mutation must happen, return copies of
--   values if they change. On failure return FailedTransform, "error message".
--   Ensure that even on error no mutations happen to state or value.
-- _describe(): => string
--   Return a string describing what the type should expect to get. This is
--   used to generate error messages for complex types that bail out of value
--   specific error messages due to complexity.
class BaseType
  -- detects if value is *instance* of base type
  @is_base_type: (val) =>
    if mt = type(val) == "table" and getmetatable val
      if mt.__class
        return mt.__class.is_base_type == BaseType.is_base_type

    false

  @__inherited: (cls) =>
    cls.__base.__call = cls.__call
    cls.__base.__eq = @__eq
    cls.__base.__div = @__div
    cls.__base.__mod = @__mod
    cls.__base.__mul = @__mul
    cls.__base.__add = @__add
    cls.__base.__unm = @__unm
    cls.__base.__tostring = @__tostring

    -- TODO: ensure things implement describe to prevent hard error when
    -- parsing inputs that don't pass the shape
    -- unless rawget cls.__base, "_describe"
    --   print "MISSING _describe", cls.__name

  __eq: (other) =>
    if BaseType\is_base_type other
      other @
    else
      @ other[1]

  __div: (fn) =>
    TransformNode @, fn

  __mod: (fn) =>
    with TransformNode @, fn
      .with_state = true

  __mul: (_left, _right) ->
    left, err = coerce_literal _left
    unless left
      error "left hand side of multiplication: #{_left}: #{err}"

    right, err = coerce_literal _right
    unless right
      error "right hand side of multiplication: #{_right}: #{err}"

    SequenceNode left, right

  __add: (_left, _right) ->
    left, err = coerce_literal _left
    unless left
      error "left hand side of addition: #{_left}: #{err}"

    right, err = coerce_literal _right
    unless right
      error "right hand side of addition: #{_right}: #{err}"

    if left.__class == FirstOfNode
      options = { unpack left.options }
      table.insert options, right
      FirstOfNode unpack options
    elseif right.__class == FirstOfNode
      FirstOfNode left, unpack right.options
    else
      FirstOfNode left, right

  __unm: (right) =>
    NotType right

  __tostring: =>
    @_describe!

  _describe: =>
    error "Node missing _describe: #{@@__name}"

  new: (opts) =>
    -- does nothing, implementing classes not expected to call super
    -- this is only here in case someone was calling super at some point

  -- test if value matches type, returns true on success
  -- if state is used, then the state object is returned instead
  check_value: (...) =>
    value, state_or_err = @_transform ...

    if value == FailedTransform
      return nil, state_or_err

    if type(state_or_err) == "table"
      state_or_err
    else
      true

  transform: (...) =>
    value, state_or_err = @_transform ...

    if value == FailedTransform
      return nil, state_or_err

    if type(state_or_err) == "table"
      value, state_or_err
    else
      value

  -- alias for transform
  repair: (...) => @transform ...

  on_repair: (fn) =>
    (@ + types.any / fn * @)\describe -> @_describe!

  is_optional: =>
    OptionalType @

  describe: (...) =>
    DescribeNode @, ...

  tag: (name) =>
    TaggedType @, {
      tag: name
    }

  clone_opts: =>
    error "clone_opts is not longer supported"

  __call: (...) =>
    @check_value ...

-- done with the division operator
class TransformNode extends BaseType
  new: (@node, @t_fn) =>
    assert @node, "missing node for transform"

  _describe: =>
    @.node\_describe!

  _transform: (value, state) =>
    value, state_or_err = @.node\_transform value, state

    if value == FailedTransform
      FailedTransform, state_or_err
    else
      out = switch type @.t_fn
        when "function"
          if @with_state
            @.t_fn(value, state_or_err)
          else
            @.t_fn(value)
        else
          @.t_fn

      out, state_or_err

class SequenceNode extends BaseType
  new: (...) =>
    @sequence = {...}

  _describe: =>
    item_names = [describe_type i for i in *@sequence]
    join_names item_names, " then "

  _transform: (value, state) =>
    for node in *@sequence
      value, state = node\_transform value, state
      if value == FailedTransform
        break

    value, state

class FirstOfNode extends BaseType
  new: (...) =>
    @options = {...}

  _describe: =>
    item_names = [describe_type i for i in *@options]
    join_names item_names, ", ", ", or "

  _transform: (value, state) =>
    unless @options[1]
      return FailedTransform, "no options for node"

    for node in *@options
      new_val, new_state = node\_transform value, state

      unless new_val == FailedTransform
        return new_val, new_state

    FailedTransform, "expected #{@_describe!}"

class DescribeNode extends BaseType
  new: (@node, describe) =>
    local err_message
    if type(describe) == "table"
      {type: describe, error: err_message} = describe

    @_describe = if type(describe) == "string"
      -> describe
    else
      describe

    @err_handler = if err_message
      if type(err_message) == "string"
        -> err_message
      else
        err_message

  _transform: (input, ...) =>
    value, state = @node\_transform input, ...

    if value == FailedTransform
      err = if @err_handler
        @.err_handler input, state
      else
        "expected #{@_describe!}"

      return FailedTransform, err

    value, state

  describe: (...) =>
    DescribeNode @node, ...

-- annotates failures with the value that failed
-- TODO: should this be part of describe?
class AnnotateNode extends BaseType
  new: (base_type, opts) =>
    @base_type = assert coerce_literal base_type
    if opts
      -- replace the format error method
      if opts.format_error
        @format_error = assert types.func\transform opts.format_error

  format_error: (value, err) =>
    "#{tostring value}: #{err}"

  _transform: (value, state) =>
    new_value, state_or_err = @base_type\_transform value, state
    if new_value == FailedTransform
      FailedTransform, @format_error value, state_or_err
    else
      new_value, state_or_err

  _describe: =>
    if @base_type._describe
      @base_type\_describe!

class TaggedType extends BaseType
  new: (@base_type, opts={}) =>
    @tag_name = assert opts.tag, "tagged type missing tag"

    @tag_type = type @tag_name

    if @tag_type == "string"
      if @tag_name\match "%[%]$"
        @tag_name = @tag_name\sub 1, -3
        @tag_array = true

  update_state: (state, value, ...) =>
    out = clone_state state

    if @tag_type == "function"
      if select("#", ...) > 0
        @.tag_name out, ..., value
      else
        @.tag_name out, value
    else
      if @tag_array
        existing = out[@tag_name]

        if type(existing) == "table"
          copy = {k,v for k,v in pairs existing}
          table.insert copy, value
          out[@tag_name] = copy
        else
          out[@tag_name] = { value }
      else
        out[@tag_name] = value

    out

  _transform: (value, state) =>
    value, state = @base_type\_transform value, state

    if value == FailedTransform
      return FailedTransform, state

    state = @update_state state, value
    value, state

  _describe: =>
    base_description = @base_type\_describe!
    "#{base_description} tagged #{describe_type @tag_name}"

class TagScopeType extends TaggedType
  new: (base_type, opts) =>
    if opts
      super base_type, opts
    else
      @base_type = base_type

  -- override to control how empty state is created for existing state
  create_scope_state: (state) =>
    nil

  _transform: (value, state) =>
    value, scope = @base_type\_transform value, @create_scope_state(state)

    if value == FailedTransform
      return FailedTransform, scope

    if @tag_name
      state = @update_state state, scope, value

    value, state

class OptionalType extends BaseType
  new: (@base_type) =>
    assert BaseType\is_base_type(@base_type), "expected a type checker"

  _transform: (value, state) =>
    return value, state if value == nil
    @base_type\_transform value, state

  is_optional: => @

  _describe: =>
    if @base_type._describe
      base_description = @base_type\_describe!
      "optional #{base_description}"

class AnyType extends BaseType
  _transform: (v, state) => v, state
  _describe: => "anything"

  -- any type is already optional (accepts nil)
  is_optional: => @

-- basic type check
class Type extends BaseType
  new: (@t, opts) =>
    if opts
      if opts.length
        @length_type = assert coerce_literal opts.length

  _transform: (value, state) =>
    got = type(value)

    if @t != got
      return FailedTransform, "expected type #{describe_type @t}, got #{describe_type got}"

    if @length_type
      len = #value
      res, state = @length_type\_transform len, state

      if res == FailedTransform
        return FailedTransform, "#{@t} length #{state}, got #{len}"

    value, state

  -- creates a clone of this type with the length operator replaced
  length: (left, right) =>
    l = if BaseType\is_base_type left
      left
    else
      types.range left, right

    Type @t, length: l

  _describe: =>
    t = "type #{describe_type @t}"
    if @length_type
      t ..= " length_type #{@length_type\_describe!}"

    t

class ArrayType extends BaseType
  _describe: => "an array"

  _transform: (value, state) =>
    return FailedTransform, "expecting table" unless type(value) == "table"

    k = 1
    for i,v in pairs value
      unless type(i) == "number"
        return FailedTransform, "non number field: #{i}"

      unless i == k
        return FailedTransform, "non array index, got #{describe_type i} but expected #{describe_type k}"

      k += 1

    value, state

class OneOf extends BaseType
  new: (@options) =>
    assert type(@options) == "table",
      "expected table for options in one_of"

    -- optimize types
    fast_opts = types.array_of types.number + types.string
    if fast_opts @options
      @options_hash = {v, true for v in *@options}

  _describe: =>
    item_names = for i in *@options
      if type(i) == "table" and i._describe
        i\_describe!
      else
        describe_type i

    "#{join_names item_names, ", ", ", or "}"

  _transform: (value, state) =>
    if @options_hash
      if @options_hash[value]
        return value, state
    else
      for item in *@options
        return value, state if item == value

        if BaseType\is_base_type item
          new_value, new_state = item\_transform value, state
          continue if new_value == FailedTransform

          return new_value, new_state

    FailedTransform, "expected #{@_describe!}"

class AllOf extends BaseType
  new: (@types) =>
    assert type(@types) == "table", "expected table for first argument"

    for checker in *@types
      assert BaseType\is_base_type(checker), "all_of expects all type checkers"

  _describe: =>
    item_names = [describe_type i for i in *@types]
    join_names item_names, " and "

  _transform: (value, state) =>
    for t in *@types
      value, state = t\_transform value, state

      if value == FailedTransform
        return FailedTransform, state

    value, state

class ArrayOf extends BaseType
  @type_err_message: "expecting table"

  new: (@expected, opts) =>
    if opts
      @keep_nils = opts.keep_nils and true
      if opts.length
        @length_type = assert coerce_literal opts.length

  _describe: =>
    "array of #{describe_type @expected}"

  _transform: (value, state) =>
    pass, err = types.table value

    unless pass
      return FailedTransform, err

    if @length_type
      len = #value
      res, state = @length_type\_transform len, state
      if res == FailedTransform
        return FailedTransform, "array length #{state}, got #{len}"

    is_literal = not BaseType\is_base_type @expected

    local copy, k

    for idx, item in ipairs value
      skip_item = false

      transformed_item = if is_literal
        if @expected != item
          return FailedTransform, "array item #{idx}: expected #{describe_type @expected}"
        else
          item
      else
        item_val, state = @expected\_transform item, state

        if item_val == FailedTransform
          return FailedTransform, "array item #{idx}: #{state}"

        if item_val == nil and not @keep_nils
          skip_item = true
        else
          item_val

      if transformed_item != item or skip_item
        unless copy
          copy = [i for i in *value[1, idx - 1]]
          k = idx

      if copy and not skip_item
        copy[k] = transformed_item
        k += 1

    copy or value, state

class ArrayContains extends BaseType
  @type_err_message: "expecting table"
  short_circuit: true
  keep_nils: false

  new: (@contains, opts) =>
    assert @contains, "missing contains"

    if opts
      @short_circuit = opts.short_circuit and true
      @keep_nils = opts.keep_nils and true

  _describe: =>
    "array containing #{describe_type @contains}"

  _transform: (value, state) =>
    pass, err = types.table value

    unless pass
      return FailedTransform, err

    is_literal = not BaseType\is_base_type @contains

    contains = false

    local copy, k

    for idx, item in ipairs value
      skip_item = false

      transformed_item = if is_literal
        -- literal can't transform
        if @contains == item
          contains = true

        item
      else
        item_val, new_state = @contains\_transform item, state
        if item_val == FailedTransform
          item
        else
          state = new_state
          contains = true
          if item_val == nil and not @keep_nils
            skip_item = true
          else
            item_val

      if transformed_item != item or skip_item
        unless copy
          copy = [i for i in *value[1, idx - 1]]
          k = idx

      if copy and not skip_item
        copy[k] = transformed_item
        k += 1

      if contains and @short_circuit
        if copy
          -- copy the rest
          for kdx=idx+1,#value
            copy[k] = value[kdx]
            k += 1

        break

    unless contains
      return FailedTransform, "expected #{@_describe!}"

    copy or value, state


class MapOf extends BaseType
  new: (expected_key, expected_value) =>
    @expected_key = coerce_literal expected_key
    @expected_value = coerce_literal expected_value

  _describe: =>
    "map of #{@expected_key\_describe!} -> #{@expected_value\_describe!}"

  _transform: (value, state) =>
    pass, err = types.table value
    unless pass
      return FailedTransform, err

    key_literal = not BaseType\is_base_type @expected_key
    value_literal = not BaseType\is_base_type @expected_value

    transformed = false

    out = {}
    for k,v in pairs value
      new_k = k
      new_v = v

      if key_literal
        if k != @expected_key
          return FailedTransform, "map key expected #{describe_type @expected_key}"
      else
        new_k, state = @expected_key\_transform k, state
        if new_k == FailedTransform
          return FailedTransform, "map key #{state}"

      if value_literal
        if v != @expected_value
          return FailedTransform, "map value expected #{describe_type @expected_value}"
      else
        new_v, state = @expected_value\_transform v, state
        if new_v == FailedTransform
          return FailedTransform, "map value #{state}"

      if new_k != k or new_v != v
        transformed = true

      continue if new_k == nil
      out[new_k] = new_v

    transformed and out or value, state

class Shape extends BaseType
  @type_err_message: "expecting table"
  open: false
  check_all: false

  new: (@shape, opts) =>
    assert type(@shape) == "table", "expected table for shape"
    if opts
      if opts.extra_fields
        assert BaseType\is_base_type(opts.extra_fields), "extra_fields_type must be type checker"
        @extra_fields_type = opts.extra_fields

      @open = opts.open and true
      @check_all = opts.check_all and true

      if @open
        assert not @extra_fields_type, "open can not be combined with extra_fields"

      if @extra_fields_type
        assert not @open, "extra_fields can not be combined with open"

  -- NOTE: the extra_fields_type is stripped
  is_open: =>
    Shape @shape, {
      open: true
      check_all: @check_all or nil
    }

  _describe: =>
    parts = for k, v in pairs @shape
      "#{describe_type k} = #{describe_type v}"

    "{ #{table.concat parts, ", "} }"

  _transform: (value, state) =>
    pass, err = types.table value
    unless pass
      return FailedTransform, err

    check_all = @check_all
    remaining_keys = {key, true for key in pairs value}

    local errors
    dirty = false
    out = {}

    for shape_key, shape_val in pairs @shape
      item_value = value[shape_key]

      if remaining_keys
        remaining_keys[shape_key] = nil

      new_val, state = if BaseType\is_base_type shape_val
        shape_val\_transform item_value, state
      else
        if shape_val == item_value
          item_value, state
        else
          FailedTransform, "expected #{describe_type shape_val}"

      if new_val == FailedTransform
        err = "field #{describe_type shape_key}: #{state}"
        if check_all
          if errors
            table.insert errors, err
          else
            errors = {err}
        else
          return FailedTransform, err
      else
        if new_val != item_value
          dirty = true

        out[shape_key] = new_val

    if remaining_keys and next remaining_keys
      if @open
        -- copy the remaining keys to out
        for k in pairs remaining_keys
          out[k] = value[k]
      elseif @extra_fields_type
        for k in pairs remaining_keys
          item_value = value[k]
          tuple, state = @extra_fields_type\_transform {[k]: item_value}, state
          if tuple == FailedTransform
            err = "field #{describe_type k}: #{state}"
            if check_all
              if errors
                table.insert errors, err
              else
                errors = {err}
            else
              return FailedTransform, err
          else
            if nk = tuple and next tuple
              -- the tuple key changed
              if nk != k
                dirty = true
              -- the value changed
              elseif tuple[nk] != item_value
                dirty = true

              out[nk] = tuple[nk]
            else
              -- value was removed, dirty
              dirty = true
      else
        names = for key in pairs remaining_keys
          describe_type key

        err = "extra fields: #{table.concat names, ", "}"

        if check_all
          if errors
            table.insert errors, err
          else
            errors = {err}
        else
          return FailedTransform, err

    if errors and next errors
      return FailedTransform, table.concat errors, "; "

    dirty and out or value, state

class Partial extends Shape
  open: true

  is_open: =>
    error "is_open has no effect on Partial"

class Pattern extends BaseType
  new: (@pattern, opts) =>
    -- TODO: we could support an lpeg object, or something that implements a match method
    assert type(@pattern) == "string", "Pattern must be a string"

    if opts
      @coerce = opts.coerce
      assert opts.initial_type == nil, "initial_type has been removed from types.pattern (got: #{opts.initial_type})"

  _describe: =>
    "pattern #{describe_type @pattern}"

  -- TODO: should we remove coerce? it can be done with operators
  _transform: (value, state) =>
    -- the value to match against, but not the value returned
    test_value = if @coerce
      if BaseType\is_base_type @coerce
        c_res, err = @coerce\_transform value

        if c_res == FailedTransform
          return FailedTransform, err

        c_res
      else
        tostring value
    else
      value

    t_res, err = types.string test_value

    unless t_res
      return FailedTransform, err

    if test_value\match @pattern
      value, state
    else
      FailedTransform, "doesn't match #{@_describe!}"

class Literal extends BaseType
  new: (@value) =>

  _describe: =>
    describe_type @value

  _transform: (value, state) =>
    if @value != value
      return FailedTransform, "expected #{@_describe!}"

    value, state

class Custom extends BaseType
  new: (@fn) =>
    assert type(@fn) == "function", "custom checker must be a function"

  _describe: =>
    "custom checker #{@fn}"

  _transform: (value, state) =>
    pass, err = @.fn value, state

    unless pass
      return FailedTransform, err or "failed custom check"

    value, state

class Equivalent extends BaseType
  values_equivalent = (a,b) ->
    return true if a == b

    if type(a) == "table" and type(b) == "table"
      seen_keys = {}

      for k,v in pairs a
        seen_keys[k] = true
        return false unless values_equivalent v, b[k]

      for k,v in pairs b
        continue if seen_keys[k]
        return false unless values_equivalent v, a[k]

      true
    else
      false

  new: (@val) =>

  _describe: =>
    "equivalent to #{describe_type @val}"

  _transform: (value, state) =>
    if values_equivalent @val, value
      value, state
    else
      FailedTransform, "not equivalent to #{@val}"

class Range extends BaseType
  new: (@left, @right) =>
    assert @left <= @right, "left range value should be less than right range value"
    @value_type = assert types[type(@left)], "couldn't figure out type of range boundary"

  _transform: (value, state) =>
    res, state = @.value_type\_transform value, state

    if res == FailedTransform
      return FailedTransform, "range #{state}"

    if value < @left
      return FailedTransform, "not in #{@_describe!}"

    if value > @right
      return FailedTransform, "not in #{@_describe!}"

    value, state

  _describe: =>
    "range from #{@left} to #{@right}"

class Proxy extends BaseType
  new: (@fn) =>

  _transform: (...) =>
    assert(@.fn!, "proxy missing transformer")\_transform ...

  _describe: (...) =>
    assert(@.fn!, "proxy missing transformer")\_describe ...

class AssertType extends BaseType
  assert: assert

  new: (@base_type) =>
    assert BaseType\is_base_type(@base_type), "expected a type checker"

  _transform: (value, state) =>
    value, state_or_err = @base_type\_transform value, state
    @.assert value != FailedTransform, state_or_err
    value, state_or_err

  _describe: =>
    if @base_type._describe
      base_description = @base_type\_describe!
      "assert #{base_description}"

class NotType extends BaseType
  new: (@base_type) =>
    assert BaseType\is_base_type(@base_type), "expected a type checker"

  _transform: (value, state) =>
    out, _ = @base_type\_transform value, state
    if out == FailedTransform
      value, state
    else
      FailedTransform, "expected #{@_describe!}"

  _describe: =>
    if @base_type._describe
      base_description = @base_type\_describe!
      "not #{base_description}"

class CloneType extends BaseType
  _transform: (value, state) =>
    switch type value
      -- literals that don't need cloning
      when "nil", "string", "number", "boolean"
        return value, state
      when "table"
        -- shallow copy
        clone_value = {k, v for k, v in pairs value}
        if mt = getmetatable value
          setmetatable clone_value, mt

        return clone_value, state
      else
        return FailedTransform, "#{describe_type value} is not cloneable"

  _describe: =>
    "cloneable value"

class MetatableIsType extends BaseType
  allow_metatable_update: false

  new: (metatable_type, opts) =>
    @metatable_type = if BaseType\is_base_type metatable_type
      metatable_type
    else
      Literal metatable_type

    if opts
      @allow_metatable_update = opts.allow_metatable_update and true

  _transform: (value, state) =>
    -- verify that type is a table
    value, state_or_err = types.table\_transform value, state
    if value == FailedTransform
      return FailedTransform, state_or_err

    mt = getmetatable value
    new_mt, state_or_err = @metatable_type\_transform mt, state_or_err

    if new_mt == FailedTransform
      return FailedTransform, "metatable expected: #{state_or_err}"

    if new_mt != mt
      if @allow_metatable_update
        setmetatable value, new_mt
      else
        -- NOTE: changing a metatable is unsafe since if a parent type ends up
        -- failing validation we can not undo the change. The only safe way to
        -- avoid the issue would be to shallow clone value but that may come
        -- with it's own consquences. Hence, you must explicitly enable
        -- metatable mutation, and you should probably pass a clone into the
        -- transform: types.clone * types.metatable_is
        return FailedTransform, "metatable was modified by a type but { allow_metatable_update = true } is not enabled"

    value, state_or_err

  _describe: =>
    "has metatable #{describe_type @metatable_type}"


type_nil = Type "nil"
type_function = Type "function"
type_number = Type "number"

types = setmetatable {
  any: AnyType!
  string: Type "string"
  number: type_number
  function: type_function
  func: type_function
  boolean: Type "boolean"
  userdata: Type "userdata"
  nil: type_nil
  null: type_nil
  table: Type "table"
  array: ArrayType!
  clone: CloneType!

  -- compound
  integer: Pattern "^%d+$", coerce: type_number / tostring

  -- type constructors
  one_of: OneOf
  all_of: AllOf
  shape: Shape
  partial: Partial
  pattern: Pattern
  array_of: ArrayOf
  array_contains: ArrayContains
  map_of: MapOf
  literal: Literal
  range: Range
  equivalent: Equivalent
  custom: Custom
  scope: TagScopeType
  proxy: Proxy
  assert: AssertType
  annotate: AnnotateNode
  metatable_is: MetatableIsType
}, __index: (fn_name) =>
  error "Type checker does not exist: `#{fn_name}`"

check_shape = (value, shape) ->
  assert shape.check_value, "missing check_value method from shape"
  shape\check_value value

is_type = (val) ->
  BaseType\is_base_type val

type_switch = (val) ->
  setmetatable { val }, { __eq: BaseType.__eq }

{ :check_shape, :types, :is_type, :type_switch, :BaseType, :FailedTransform, VERSION: "2.5.0" }
