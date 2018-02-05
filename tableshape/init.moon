local OptionalType, TaggedType, types

-- metatable to identify arrays for merging
TagValueArray = {}
FailedTransform = {}

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


local TransformNode, SequenceNode, FirstOfNode

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

  has_repair: =>
    @opts and @opts.repair

  transform: (...) =>
    val, state_or_err = @_transform ...
    if val == FailedTransform
      return nil, state_or_err

    if type(state_or_err) == "table"
      val, state_or_err
    else
      val

  _transform: (val, state) =>
    state, err = @check_value val, state
    if state
      val, state
    else
      FailedTransform, err

  repair: (val, fix_fn) =>
    fixed = false

    pass, err = @check_value val

    unless pass
      fix_fn or= @opts and @opts.repair
      assert fix_fn, "missing repair function for: #{err}"

      fixed = true
      val = fix_fn val, err

    val, fixed

  is_optional: =>
    OptionalType @

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

    FailedTransform, "expecting one of: (#{table.concat errors or {"no options"}, "; "})"

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
    assert BaseType\is_base_type(base_type) and base_type.check_value, "expected a type checker"
    if (@base_type.opts or {}).repair and not (@opts or {}).repair
      @opts or= {}
      @opts.repair = @base_type.opts.repair

  check_value: (value, state) =>
    return state or true if value == nil
    @base_type\check_value value, state

  is_optional: => @

  on_repair: (repair_fn) =>
    OptionalType @base_type, @clone_opts repair: repair_fn

  repair: (value, fix_fn) =>
    fix_fn or= @opts and @opts.repair
    fix_fn or= @base_type\repair
    super value, fix_fn

  describe: =>
    if @base_type.describe
      base_description = @base_type\describe!
      "optional #{base_description}"

class AnyType extends BaseType
  check_value: (v, state) => state or true

  -- any type is already optional (accepts nil)
  is_optional: => @

-- basic type check
class Type extends BaseType
  new: (@t, @opts) =>
    super!

  on_repair: (repair_fn) =>
    Type @t, @clone_opts repair: repair_fn

  check_value: (value, state) =>
    got = type(value)

    if @t != got
      return nil, "got type `#{got}`, expected `#{@t}`"

    state or true

  describe: =>
    "type `#{@t}`"

class ArrayType extends BaseType
  new: (@opts) =>
    super!

  on_repair: (repair_fn) =>
    ArrayType @clone_opts repair: repair_fn

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
  new: (@items, @opts) =>
    super!
    assert type(@items) == "table", "expected table for items in one_of"

  on_repair: (repair_fn) =>
    OneOf @items, @clone_opts repair: repair_fn

  -- go through all items, repairing if possible
  repair: (value, fn) =>
    for item in *@items
      if value == item
        return value, false

      continue unless BaseType\is_base_type(item) and item\has_repair!

      res, fixed = item\repair value
      if fixed and item\check_value res
        -- short circuit on a successful repair
        return res, fixed

    -- try own repair function
    super value, fn

  describe: =>
    item_names = for i in *@items
      if type(i) == "table" and i.describe
        i\describe!
      else
        "`#{i}`"

    "one of: #{table.concat item_names, ", "}"

  check_value: (value, state) =>
    for item in *@items
      return state or true if item == value

      if BaseType\is_base_type(item) and item.check_value
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

  on_repair: (repair_fn) =>
    AllOf @types, @clone_opts repair: repair_fn

  -- repair with every checker
  repair: (val, repair_fn) =>
    has_own_repair = @has_repair! or repair_fn

    repairs = 0

    for t in *@types
      continue unless t\has_repair!
      repairs += 1
      val, fixed = t\repair val

      if fixed and not t\check_value val
        -- short circuit if repair fails
        return val, fixed

    if repairs == 0 or @has_repair!
      super val, repair_fn
    else
      val, true

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
    @keep_nils = @opts and @opts.keep_nils
    super!

  on_repair: (repair_fn) =>
    ArrayOf @expected, @clone_opts repair: repair_fn

  repair: (tbl, fix_fn) =>
    unless type(tbl) == "table"
      fix_fn or= @opts and @opts.repair
      assert fix_fn, "missing repair function for: #{@@type_err_message}"
      return fix_fn("table_invalid", @@type_err_message, tbl), true

    fixed = false
    local copy

    if BaseType\is_base_type(@expected) and @expected.repair
      -- use the repair function built into type checker
      for idx, item in ipairs tbl
        item_value, item_fixed = @expected\repair item
        if item_fixed
          fixed = true
          copy or= [v for v in *tbl[1,(idx - 1)]]
          if item_value != nil
            table.insert copy, item_value
        else
          if copy
            table.insert copy, item
    else
      for idx, item in ipairs tbl
        pass, err = @check_field idx, item, tbl
        if pass
          if copy
            table.insert copy, item
        else
          fix_fn or= @opts and @opts.repair
          assert fix_fn, "missing repair function for: #{err}"

          fixed = true
          copy or= [v for v in *tbl[1,(idx - 1)]]
          table.insert copy, fix_fn "field_invalid", idx, item

    copy or tbl, fixed

  _transform: (value, state) =>
    pass, err = types.table value
    unless pass
      return FailedTransform, err

    is_literal = not BaseType\is_base_type @expected

    local new_state
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

    if BaseType\is_base_type(@expected) and @expected.check_value
      state, err = @expected\check_value value, state
      unless state
        return nil, "item #{key} in array does not match: #{err}"
    else
      return nil, "item #{key} in array does not match `#{@expected}`"

    state or true

  check_value: (value, state) =>
    return nil, "expected table for array_of" unless type(value) == "table"

    local new_state

    for idx, item in ipairs value
      new_state, err = @check_field idx, item, value, new_state
      unless new_state
        return nil, err

    merge_tag_state state, new_state

class MapOf extends BaseType
  -- TODO: this needs its own repair implementation

  new: (@expected_key, @expected_value, @opts) =>
    super!

  on_repair: (repair_fn) =>
    MapOf @expected_key, @expected_value, @clone_opts repair: repair_fn

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

  on_repair: (repair_fn) =>
    Shape @shape, @clone_opts repair: repair_fn

  -- don't allow extra fields
  is_open: =>
    Shape @shape, @clone_opts open: true

  _transform: (value, state) =>
    pass, err = types.table value
    unless pass
      return FailedTransform, err

    remaining_keys = {key, true for key in pairs value}

    local errors
    out = {}
    local new_state

    for shape_key, shape_val in pairs @shape
      item_value = value[shape_key]

      if remaining_keys
        remaining_keys[shape_key] = nil

      new_val, tuple_state = shape_val\_transform item_value

      if new_val == FailedTransform
        unless errors
          errors = {}
        table.insert errors, "field `#{shape_key}`: #{tuple_state}"
      else
        new_state = merge_tag_state new_state, tuple_state
        out[shape_key] = new_val

    if remaining_keys and next remaining_keys
      if @opts and @opts.open
        -- add the remaining keys to out
        for k in pairs remaining_keys
          out[k] = value[k]

      else
        names = for key in pairs remaining_keys
          "`#{key}`"

        unless errors
          errors = {}

        table.insert errors,
          "extra fields: #{table.concat names, ", "}"

    if errors and next errors
      return FailedTransform, table.concat errors, "; "

    out, new_state

  repair: (tbl, fix_fn) =>
    unless type(tbl) == "table"
      fix_fn or= @opts and @opts.repair
      assert fix_fn, "missing repair function for: #{@@type_err_message}"
      return fix_fn("table_invalid", @@type_err_message, tbl), true

    fixed = false

    remaining_keys = unless @opts and @opts.open
      {key, true for key in pairs tbl}

    local copy

    for shape_key, shape_val in pairs @shape
      item_value = tbl[shape_key]

      if remaining_keys
        remaining_keys[shape_key] = nil

      -- does the value know how to repair itself?
      if BaseType\is_base_type(shape_val) and shape_val.repair
        field_value, field_fixed = shape_val\repair item_value
        if field_fixed
          copy or= {k,v for k,v in pairs tbl}
          fixed = true
          copy[shape_key] = field_value
      else
        -- check the field, repair with table's repair function
        pass, err = @check_field shape_key, item_value, shape_val, tbl
        unless pass
          fix_fn or= @opts and @opts.repair
          assert fix_fn, "missing repair function for: #{err}"
          fixed = true
          copy or= {k,v for k,v in pairs tbl}
          copy[shape_key] = fix_fn "field_invalid", shape_key, item_value, err, shape_val

    if remaining_keys and next remaining_keys
      fix_fn or= @opts and @opts.repair
      copy or= {k,v for k,v in pairs tbl}

      unless fix_fn
        keys = [tostring key for key in pairs remaining_keys]
        error "missing repair function for: extra fields (#{table.concat keys, ", "})"

      for k in pairs remaining_keys
        fixed = true
        copy[k] = fix_fn "extra_field", k, copy[k]

    copy or tbl, fixed

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

    remaining_keys = unless @opts and @opts.open
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
      if extra_key = next remaining_keys
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

  on_repair: (repair_fn) =>
    Pattern @pattern, @clone_opts repair: repair_fn

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

  on_repair: (repair_fn) =>
    Literal @value, @clone_opts repair: repair_fn

  check_value: (val, state) =>
    if @value != val
      return nil, "got `#{val}`, expected `#{@value}`"

    state or true

class Custom extends BaseType
  new: (@fn, @opts) =>
    super!

  describe: =>
    @opts.describe or "custom checker #{@fn}"

  on_repair: (repair_fn) =>
    Custom @fn, @clone_opts repair: repair_fn

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

  on_repair: (repair_fn) =>
    Equivalent @val, @clone_opts repair: repair_fn

  check_value: (val, state) =>
    if values_equivalent @val, val
      state or true
    else
      nil, "#{val} is not equivalent to #{@val}"

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
