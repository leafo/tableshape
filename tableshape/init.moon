local OptionalType, TaggedType, types

-- metatable to identify arrays for merging
TagValueArray = {}
FailedTransform = {}

unpack = unpack or table.unpack

merge_tag_state = (existing, new_tags) ->
  if type(new_tags) == "table" and type(existing) == "table"
    for k,v in pairs new_tags
      ev = existing[k]
      if ev and getmetatable(ev) == TagValueArray and getmetatable(v) == TagValueArray
        for array_val in *v
          table.insert ev, array_val
      else
        existing[k] = v

    return existing

  new_tags or existing or true


local TransformNode, SequenceNode, FirstOfNode, DescribeNode

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
    cls.__base.__mul = @__mul
    cls.__base.__add = @__add

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

  __mul: (right) =>
    SequenceNode @, right

  __add: (right) =>
    if @__class == FirstOfNode
      options = { unpack @options }
      table.insert options, right
      FirstOfNode unpack options
    else
      FirstOfNode @, right

  new: =>
    if @opts
      @describe = @opts.describe

  check_value: =>
    error "override me"

  transform: (...) =>
    val, state_or_err = @_transform ...
    if val == FailedTransform
      return nil, state_or_err

    if type(state_or_err) == "table"
      val, state_or_err
    else
      val

  -- alias for transform
  repair: (...) => @transform ...

  _transform: (val, state) =>
    state, err = @check_value val, state
    if state
      val, state
    else
      FailedTransform, err

  on_repair: (fn) =>
    @ + types.any / fn * @

  is_optional: =>
    OptionalType @

  on_describe: (...) =>
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

  check_value: (value, state) =>
    @node\check_value value, state

  _transform: (value, state) =>
    val, state_or_err = @.node\_transform value, state

    if val == FailedTransform
      val, state_or_err
    else
      out = switch type @.t_fn
        when "function"
          @.t_fn(val)
        else
          @.t_fn

      out, state_or_err

class SequenceNode extends BaseType
  @transformer: true

  new: (...) =>
    @sequence = {...}

  check_value: (value, state) =>
    local new_state

    for node in *@sequence
      pass, new_state = node\check_value value, new_state

      unless pass
        return nil, new_state

    merge_tag_state state, new_state

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

  check_value: (value, state) =>
    local errors

    for node in *@options
      pass, new_state_or_err = node\check_value value

      if pass
        return merge_tag_state state, new_state_or_err
      else
        if errors
          table.insert errors, new_state_or_err
        else
          errors = {new_state_or_err}


    nil, "no matching option (#{table.concat errors or {"no options"}, "; "})"

  _transform: (value, state) =>
    local errors

    unless @options[1]
      return FailedTransform, "no options for node"

    for node in *@options
      new_val, new_state_or_err = node\_transform value, state
      if new_val == FailedTransform
        if errors
          table.insert errors, new_state_or_err
        else
          errors = {new_state_or_err}
      else
        return new_val, new_state_or_err

    FailedTransform, "no matching option (#{table.concat errors or {"no options"}, "; "})"

class DescribeNode extends BaseType
  new: (@node, @describe) =>
    if type(@describe) == "string"
      text = @describe
      @describe = -> text

  check_value: (...) =>
    state, err = @node\check_value ...
    unless state
      return nil, @describe ...

    state, err

  _transform: (...) =>
    value, state = @node\_transform ...

    if value == FailedTransform
      return FailedTransform, @describe ...

    value, state

class TaggedType extends BaseType
  new: (@base_type, opts) =>
    @tag = assert opts.tag, "tagged type missing tag"
    if @tag\match "%[%]$"
      @tag = @tag\sub 1, -3
      @array = true

  _transform: (value, state) =>
    value, state = @base_type\_transform value, state

    if value == FailedTransform
      return FailedTransform, state

    unless type(state) == "table"
      state = {}

    if @array
      existing = state[@tag]
      if type(existing) == "table"
        table.insert existing, value
      else
        state[@tag] = setmetatable {value}, TagValueArray
    else
      state[@tag] = value

    value, state

  check_value: (value, state) =>
    state = @base_type\check_value value, state

    if state
      unless type(state) == "table"
        state = {}

      if @array
        existing = state[@tag]
        if type(existing) == "table"
          table.insert existing, value
        else
          state[@tag] = setmetatable {value}, TagValueArray
      else
        state[@tag] = value

      state

  describe: =>
    if @base_type.describe
      base_description = @base_type\describe!
      "#{base_description} tagged `#{@tag}`"

class OptionalType extends BaseType
  new: (@base_type, @opts) =>
    super!
    assert BaseType\is_base_type(base_type), "expected a type checker"

  check_value: (value, state) =>
    return state or true if value == nil
    @base_type\check_value value, state

  is_optional: => @

  describe: =>
    if @base_type.describe
      base_description = @base_type\describe!
      "optional #{base_description}"

class AnyType extends BaseType
  check_value: (v, state) => state or true
  _transform: (v, state) => v, state

  -- any type is already optional (accepts nil)
  is_optional: => @

-- basic type check
class Type extends BaseType
  new: (@t, @opts) =>
    if @opts
      @length_type = @opts.length

    super!

  check_value: (value, state) =>
    got = type(value)

    if @t != got
      return nil, "got type `#{got}`, expected `#{@t}`"

    if @length_type
      state, len_fail = @length_type\check_value #value, state
      unless state
        return nil, "#{@t} length #{len_fail}"

    state or true

  length: (left, right) =>
    l = if BaseType\is_base_type left
      left
    else
      types.range left, right

    Type @t, @clone_opts length: l

  describe: =>
    t = "type `#{@t}`"
    if @length_type
      t ..= " length_type #{@length_type\describe!}"

    t

class ArrayType extends BaseType
  new: (@opts) =>
    super!

  check_value: (value, state) =>
    return nil, "expecting table" unless type(value) == "table"

    k = 1
    for i,v in pairs value
      unless type(i) == "number"
        return nil, "non number field: #{i}"

      unless i == k
        return nil, "non array index, got `#{i}` but expected `#{k}`"

      k += 1

    state or true

class OneOf extends BaseType
  new: (@options, @opts) =>
    super!
    assert type(@options) == "table",
      "expected table for options in one_of"

    -- optimize types
    fast_opts = types.array_of types.number + types.string
    if fast_opts @options
      @options_hash = {v, true for v in *@options}

  describe: =>
    item_names = for i in *@options
      if type(i) == "table" and i.describe
        i\describe!
      else
        "`#{i}`"

    "one of: #{table.concat item_names, ", "}"

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

    FailedTransform, "value `#{value}` does not match #{@describe!}"

  check_value: (value, state) =>
    if @options_hash
      if @options_hash[value]
        return state or true
    else
      for item in *@options
        return state or true if item == value

        if BaseType\is_base_type(item)
          new_state = item\check_value value
          if new_state
            return merge_tag_state state, new_state

    nil, "value `#{value}` does not match #{@describe!}"

class AllOf extends BaseType
  new: (@types, @opts) =>
    super!
    assert type(@types) == "table", "expected table for first argument"

    for checker in *@types
      assert BaseType\is_base_type(checker), "all_of expects all type checkers"

  check_value: (value, state) =>
    new_state = nil

    for t in *@types
      new_state, err = t\check_value value, new_state
      unless new_state
        return nil, err

    merge_tag_state state, new_state

class ArrayOf extends BaseType
  @type_err_message: "expecting table"

  new: (@expected, @opts) =>
    if @opts
      @keep_nils = @opts.keep_nils
      @length_type = @opts.length

    super!

  _transform: (value, state) =>
    pass, err = types.table value
    unless pass
      return FailedTransform, err

    local new_state

    if @length_type
      new_state, len_fail = @length_type\check_value #value, new_state
      unless new_state
        return FailedTransform, "array length #{len_fail}"

    is_literal = not BaseType\is_base_type @expected

    out = {}

    out = for idx, item in ipairs value
      if is_literal
        if @expected != item
          return FailedTransform, "array item #{idx}: got `#{item}`, expected `#{@expected}`"
        else
          item
      else
        val, new_state = @expected\_transform item, new_state

        if val == FailedTransform
          return FailedTransform, "array item #{idx}: #{new_state}"

        if val == nil and not @keep_nils
          continue

        val

    out, merge_tag_state state, new_state

  check_field: (key, value, tbl, state) =>
    return state or true if value == @expected

    if BaseType\is_base_type @expected
      state, err = @expected\check_value value, state
      unless state
        return nil, "item #{key} in array does not match: #{err}"
    else
      return nil, "item #{key} in array does not match `#{@expected}`"

    state or true

  check_value: (value, state) =>
    return nil, "expected table for array_of" unless type(value) == "table"

    local new_state

    if @length_type
      new_state, len_fail = @length_type\check_value #value, new_state
      unless new_state
        return nil, "array length #{len_fail}"

    for idx, item in ipairs value
      new_state, err = @check_field idx, item, value, new_state
      unless new_state
        return nil, err

    merge_tag_state state, new_state

class MapOf extends BaseType
  new: (@expected_key, @expected_value, @opts) =>
    super!

  _transform: (value, state) =>
    pass, err = types.table value
    unless pass
      return FailedTransform, err

    local new_state

    key_literal = not BaseType\is_base_type @expected_key
    value_literal = not BaseType\is_base_type @expected_value

    out = {}
    for k,v in pairs value
      if key_literal
        if k != @expected_key
          return FailedTransform, "map key got `#{k}`, expected `#{@expected_key}`"
      else
        k, new_state = @expected_key\_transform k, new_state
        if k == FailedTransform
          return FailedTransform, "map key #{new_state}"

      if value_literal
        if v != @expected_value
          return FailedTransform, "map value got `#{v}`, expected `#{@expected_value}`"
      else
        v, new_state = @expected_value\_transform v, new_state
        if v == FailedTransform
          return FailedTransform, "map value #{new_state}"

      continue if k == nil
      out[k] = v

    out, merge_tag_state state, new_state

  check_value: (value, state) =>
    return nil, "expected table for map_of" unless type(value) == "table"

    local new_state

    for k,v in pairs value
      -- check key
      if @expected_key.check_value
        new_state, err = @expected_key\check_value k, new_state
        unless new_state
          return nil, "field `#{k}` in table does not match: #{err}"

      else
        unless @expected_key == k
          return nil, "field `#{k}` does not match `#{@expected_key}`"

      -- check value
      if @expected_value.check_value
        new_state, err = @expected_value\check_value v, new_state
        unless new_state
          return nil, "field `#{k}` value in table does not match: #{err}"

      else
        unless @expected_value == v
          return nil, "field `#{k}` value does not match `#{@expected_value}`"

    merge_tag_state state, new_state

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

  _transform: (value, state) =>
    pass, err = types.table value
    unless pass
      return FailedTransform, err

    check_all = @check_all
    remaining_keys = {key, true for key in pairs value}

    local errors
    out = {}
    local new_state

    for shape_key, shape_val in pairs @shape
      item_value = value[shape_key]

      if remaining_keys
        remaining_keys[shape_key] = nil

      new_val, tuple_state = if BaseType\is_base_type shape_val
        shape_val\_transform item_value, new_state
      else
        if shape_val == item_value
          item_value, new_state
        else
          FailedTransform, "`#{shape_val}` does not equal `#{item_value}`"

      if new_val == FailedTransform
        err = "field `#{shape_key}`: #{tuple_state}"
        if check_all
          if errors
            table.insert errors, err
          else
            errors = {err}
        else
          return FailedTransform, err
      else
        new_state = tuple_state
        out[shape_key] = new_val

    if remaining_keys and next remaining_keys
      if @open
        -- copy the remaining keys to out
        for k in pairs remaining_keys
          out[k] = value[k]
      elseif @extra_fields_type
        for k in pairs remaining_keys
          tuple, tuple_state = @.extra_fields_type\_transform {[k]: value[k]}, new_state
          if tuple == FailedTransform
            err = "field `#{k}`: #{tuple_state}"
            if check_all
              if errors
                table.insert errors, err
              else
                errors = {err}
            else
              return FailedTransform, err
          else
            new_state = tuple_state
            if nk = tuple and next tuple
              out[nk] = tuple[nk]
      else
        names = for key in pairs remaining_keys
          "`#{key}`"

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

    out, merge_tag_state state, new_state

  check_field: (key, value, expected_value, tbl, state) =>
    return state or true if value == expected_value

    if BaseType\is_base_type(expected_value) and expected_value.check_value
      state, err = expected_value\check_value value, state

      unless state
        return nil, "field `#{key}`: #{err}", err
    else
      err = "expected `#{expected_value}`, got `#{value}`"
      return nil, "field `#{key}` #{err}", err

    state or true

  check_fields: (value, short_circuit=false) =>
    unless type(value) == "table"
      if short_circuit
        return nil, @@type_err_message
      else
        return nil, { @@type_err_message }

    errors = unless short_circuit then {}

    state = nil

    remaining_keys = if not @open
      {key, true for key in pairs value}

    for shape_key, shape_val in pairs @shape
      item_value = value[shape_key]

      if remaining_keys
        remaining_keys[shape_key] = nil

      state, err, standalone_err = @check_field shape_key, item_value, shape_val, value, state

      unless state
        if short_circuit
          return nil, err
        else
          errors[shape_key] = standalone_err or err
          table.insert errors, err

    if remaining_keys
      if @extra_fields_type
        for k in pairs remaining_keys
          tuple_state, tuple_err = @.extra_fields_type\check_value {[k]: value[k]}, state
          if tuple_state
            state = tuple_state
          else
            if short_circuit
              return nil, tuple_err
            else
              return nil, { tuple_err }
      elseif extra_key = next remaining_keys
        msg = "has extra field: `#{extra_key}`"
        if short_circuit
          return nil, msg
        else
          return nil, { msg }

    if errors
      return nil, errors

    state or true

  check_value: (value, state) =>
    new_state, err = @check_fields value, true

    if new_state
      merge_tag_state state, new_state
    else
      nil, err

class Pattern extends BaseType
  new: (@pattern, @opts) =>
    super!

  describe: =>
    "pattern `#{@pattern}`"

  check_value: (value, state) =>
    if initial = @opts and @opts.initial_type
      return nil, "expected `#{initial}`" unless type(value) == initial

    value = tostring value if @opts and @opts.coerce

    return nil, "expected string for value" unless type(value) == "string"

    if value\match @pattern
      state or true
    else
      nil, "doesn't match pattern `#{@pattern}`"

class Literal extends BaseType
  new: (@value, @opts) =>
    super!

  describe: =>
    "literal `#{@value}`"

  check_value: (val, state) =>
    if @value != val
      return nil, "got `#{val}`, expected `#{@value}`"

    state or true

class Custom extends BaseType
  new: (@fn, @opts) =>
    super!

  describe: =>
    @opts.describe or "custom checker #{@fn}"

  check_value: (val, state) =>
    pass, err = @.fn val, @

    unless pass
      return nil, err or "#{val} is invalid"

    state or true

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

  check_value: (val, state) =>
    if values_equivalent @val, val
      state or true
    else
      nil, "#{val} is not equivalent to #{@val}"



class Range extends BaseType
  new: (@left, @right, @opts) =>
    super!
    assert @left <= @right, "left range value should be less than right range value"
    @value_type = assert types[type(@left)], "couldn't figure out type of range boundary"

  check_value: (value, state) =>
    pass, err = @.value_type\check_value value

    unless pass
      return nil, "range #{err}"

    if value < @left
      return nil, "`#{value}` is not in #{@describe!}"

    if value > @right
      return nil, "`#{value}` is not in #{@describe!}"

    state or true

  describe: =>
    "range [#{@left}, #{@right}]"

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
  pattern: Pattern
  array_of: ArrayOf
  map_of: MapOf
  literal: Literal
  range: Range
  equivalent: Equivalent
  custom: Custom
}, __index: (fn_name) =>
  error "Type checker does not exist: `#{fn_name}`"

check_shape = (value, shape) ->
  assert shape.check_value, "missing check_value method from shape"
  shape\check_value value

is_type = (val) ->
  BaseType\is_base_type val

type_switch = (val) ->
  setmetatable { val }, { __eq: BaseType.__eq }

{ :check_shape, :types, :is_type, :type_switch, :BaseType, VERSION: "1.2.1" }
