local OptionalType, TaggedType, types

-- metatable to identify arrays for merging
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


local BaseType, TransformNode, SequenceNode, FirstOfNode, DescribeNode, NotType

describe_literal = (val) ->
  switch type(val)
    when "string"
      if not val\match '"'
        "\"#{val}\""
      elseif not val\match "'"
        "'#{val}'"
      else
        "`#{val}`"
    else
      if BaseType\is_base_type val
        val\_describe!
      else
        tostring val

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

class BaseType
  @is_base_type: (val) =>
    return false unless type(val) == "table"

    cls = val and val.__class
    return false unless cls
    return true if BaseType == cls
    @is_base_type cls.__parent

  @__inherited: (cls) =>
    cls.__base.__call = cls.__call
    cls.__base.__eq = @__eq
    cls.__base.__div = @__div
    cls.__base.__mod = @__mod
    cls.__base.__mul = @__mul
    cls.__base.__add = @__add
    cls.__base.__unm = @__unm

    mt = getmetatable cls
    create = mt.__call
    mt.__call = (cls, ...) ->
      ret = create cls, ...
      if ret.opts and ret.opts.optional
        ret\is_optional!
      else
        ret

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

  __mul: (right) =>
    SequenceNode @, right

  __add: (right) =>
    if @__class == FirstOfNode
      options = { unpack @options }
      table.insert options, right
      FirstOfNode unpack options
    else
      FirstOfNode @, right

  __unm: (right) =>
    NotType right

  _describe: =>
    error "Node missing _describe: #{@@__name}"

  new: =>
    if @opts
      @_describe = @opts.describe

  -- like repair but only returns true or false
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

  clone_opts: (merge) =>
    opts = if @opts
      {k,v for k,v in pairs @opts}
    else
      {}

    if merge
      for k, v in pairs merge
        opts[k] = v

    opts

  __call: (...) =>
    @check_value ...

-- done with the division operator
class TransformNode extends BaseType
  @transformer: true

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
  @transformer: true

  new: (...) =>
    @sequence = {...}

  _describe: =>
    item_names = for i in *@sequence
      if type(i) == "table" and i._describe
        i\_describe!
      else
        describe_literal i

    join_names item_names, " then "

  _transform: (value, state) =>
    for node in *@sequence
      value, state = node\_transform value, state
      if value == FailedTransform
        break

    value, state

class FirstOfNode extends BaseType
  @transformer: true

  new: (...) =>
    @options = {...}

  _describe: =>
    item_names = for i in *@options
      if type(i) == "table" and i._describe
        i\_describe!
      else
        describe_literal i

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

class TaggedType extends BaseType
  new: (@base_type, opts) =>
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
    "#{base_description} tagged #{describe_literal @tag}"

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
  new: (@base_type, @opts) =>
    super!
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
  new: (@t, @opts) =>
    if @opts
      @length_type = @opts.length

    super!

  _transform: (value, state) =>
    got = type(value)

    if @t != got
      return FailedTransform, "expected type #{describe_literal @t}, got #{describe_literal got}"

    if @length_type
      len = #value
      res, state = @length_type\_transform len, state

      if res == FailedTransform
        return FailedTransform, "#{@t} length #{state}, got #{len}"

    value, state

  length: (left, right) =>
    l = if BaseType\is_base_type left
      left
    else
      types.range left, right

    Type @t, @clone_opts length: l

  _describe: =>
    t = "type #{describe_literal @t}"
    if @length_type
      t ..= " length_type #{@length_type\_describe!}"

    t

class ArrayType extends BaseType
  new: (@opts) =>
    super!

  _describe: => "an array"

  _transform: (value, state) =>
    return FailedTransform, "expecting table" unless type(value) == "table"

    k = 1
    for i,v in pairs value
      unless type(i) == "number"
        return FailedTransform, "non number field: #{i}"

      unless i == k
        return FailedTransform, "non array index, got #{describe_literal i} but expected #{describe_literal k}"

      k += 1

    value, state

class OneOf extends BaseType
  new: (@options, @opts) =>
    super!
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
        describe_literal i

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
  new: (@types, @opts) =>
    super!
    assert type(@types) == "table", "expected table for first argument"

    for checker in *@types
      assert BaseType\is_base_type(checker), "all_of expects all type checkers"

  _describe: =>
    item_names = for i in *@types
      if type(i) == "table" and i._describe
        i\_describe!
      else
        describe_literal i

    join_names item_names, " and "

  _transform: (value, state) =>
    for t in *@types
      value, state = t\_transform value, state

      if value == FailedTransform
        return FailedTransform, state

    value, state

class ArrayOf extends BaseType
  @type_err_message: "expecting table"

  new: (@expected, @opts) =>
    if @opts
      @keep_nils = @opts.keep_nils
      @length_type = @opts.length

    super!

  _describe: =>
    "array of #{describe_literal @expected}"

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
          return FailedTransform, "array item #{idx}: expected #{describe_literal @expected}"
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

class MapOf extends BaseType
  new: (@expected_key, @expected_value, @opts) =>
    super!

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
          return FailedTransform, "map key expected #{describe_literal @expected_key}"
      else
        new_k, state = @expected_key\_transform k, state
        if new_k == FailedTransform
          return FailedTransform, "map key #{state}"

      if value_literal
        if v != @expected_value
          return FailedTransform, "map value expected #{describe_literal @expected_value}"
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

  new: (@shape, @opts) =>
    super!
    assert type(@shape) == "table", "expected table for shape"
    if @opts
      @extra_fields_type = @opts.extra_fields
      @open = @opts.open
      @check_all = @opts.check_all

      if @open
        assert not @extra_fields_type, "open can not be combined with extra_fields"

      if @extra_fields_type
        assert not @open, "extra_fields can not be combined with open"

  -- allow extra fields
  is_open: =>
    Shape @shape, @clone_opts open: true

  _describe: =>
    parts = for k, v in pairs @shape
      "#{describe_literal k} = #{describe_literal v}"

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
          FailedTransform, "expected #{describe_literal shape_val}"

      if new_val == FailedTransform
        err = "field #{describe_literal shape_key}: #{state}"
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
          tuple, state = @.extra_fields_type\_transform {[k]: item_value}, state
          if tuple == FailedTransform
            err = "field #{describe_literal k}: #{state}"
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
          describe_literal key

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
  new: (@pattern, @opts) =>
    super!

  _describe: =>
    "pattern #{describe_literal @pattern}"

  -- TODO: remove coerce, can be done with operators
  _transform: (value, state) =>
    if initial = @opts and @opts.initial_type
      return FailedTransform, "expected #{describe_literal initial}" unless type(value) == initial

    value = tostring value if @opts and @opts.coerce

    t_res, err = types.string value

    unless t_res
      return FailedTransform, err

    if value\match @pattern
      value, state
    else
      FailedTransform, "doesn't match #{@_describe!}"

class Literal extends BaseType
  new: (@value, @opts) =>
    super!

  _describe: =>
    describe_literal @value

  _transform: (value, state) =>
    if @value != value
      return FailedTransform, "expected #{@_describe!}"

    value, state

class Custom extends BaseType
  new: (@fn, @opts) =>
    super!

  _describe: =>
    @opts and @opts.describe or "custom checker #{@fn}"

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

  new: (@val, @opts) =>
    super!

  _transform: (value, state) =>
    if values_equivalent @val, value
      value, state
    else
      FailedTransform, "not equivalent to #{@val}"

class Range extends BaseType
  new: (@left, @right, @opts) =>
    super!
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
  new: (@fn, @opts) =>

  _transform: (...) =>
    assert(@.fn!, "proxy missing transformer")\_transform ...

  _describe: (...) =>
    assert(@.fn!, "proxy missing transformer")\_describe ...

class AssertType extends BaseType
  new: (@base_type, @opts) =>
    super!
    assert BaseType\is_base_type(@base_type), "expected a type checker"

  _transform: (value, state) =>
    value, state_or_err = @base_type\_transform value, state
    assert value != FailedTransform, state_or_err
    value, state_or_err

  _describe: =>
    if @base_type._describe
      base_description = @base_type\_describe!
      "assert #{base_description}"

class NotType extends BaseType
  new: (@base_type, @opts) =>
    super!
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

types = setmetatable {
  any: AnyType!
  string: Type "string"
  number: Type "number"
  function: Type "function"
  func: Type "function"
  boolean: Type "boolean"
  userdata: Type "userdata"
  nil: Type "nil"
  table: Type "table"
  array: ArrayType!

  -- compound
  integer: Pattern "^%d+$", coerce: true, initial_type: "number"

  -- type constructors
  one_of: OneOf
  all_of: AllOf
  shape: Shape
  partial: Partial
  pattern: Pattern
  array_of: ArrayOf
  map_of: MapOf
  literal: Literal
  range: Range
  equivalent: Equivalent
  custom: Custom
  scope: TagScopeType
  proxy: Proxy
  assert: AssertType
}, __index: (fn_name) =>
  error "Type checker does not exist: `#{fn_name}`"

check_shape = (value, shape) ->
  assert shape.check_value, "missing check_value method from shape"
  shape\check_value value

is_type = (val) ->
  BaseType\is_base_type val

type_switch = (val) ->
  setmetatable { val }, { __eq: BaseType.__eq }

{ :check_shape, :types, :is_type, :type_switch, :BaseType, :FailedTransform, VERSION: "2.0.0" }
