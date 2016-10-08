local OptionalType

class BaseType
  @is_base_type: (val) =>
    return false unless type(val) == "table"

    cls = val and val.__class
    return false unless cls
    return true if BaseType == cls
    @is_base_type cls.__parent

  @__inherited: (cls) =>
    cls.__base.__call = cls.__call

    mt = getmetatable cls
    create = mt.__call
    mt.__call = (cls, ...) ->
      ret = create cls, ...
      if ret.opts and ret.opts.optional
        ret\is_optional!
      else
        ret

  check_value: =>
    error "override me"

  has_repair: =>
    @opts and @opts.repair

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

class OptionalType extends BaseType
  new: (@base_type, @opts) =>
    assert BaseType\is_base_type(base_type) and base_type.check_value, "expected a type checker"
    if (@base_type.opts or {}).repair and not (@opts or {}).repair
      @opts or= {}
      @opts.repair = @base_type.opts.repair

  check_value: (value) =>
    return true if value == nil
    @base_type\check_value value

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
  check_value: => true
  is_optional: => AnyType

-- basic type check
class Type extends BaseType
  new: (@t, @opts) =>

  on_repair: (repair_fn) =>
    Type @t, @clone_opts repair: repair_fn

  check_value: (value) =>
    got = type(value)
    if @t != got
      return nil, "got type `#{got}`, expected `#{@t}`"
    true

  describe: =>
    "type `#{@t}`"

class ArrayType extends BaseType
  new: (@opts) =>

  on_repair: (repair_fn) =>
    ArrayType @clone_opts repair: repair_fn

  check_value: (value) =>
    return nil, "expecting table" unless type(value) == "table"

    k = 1
    for i,v in pairs value
      unless type(i) == "number"
        return nil, "non number field: #{i}"

      unless i == k
        return nil, "non array index, got `#{i}` but expected `#{k}`"

      k += 1

    true

class OneOf extends BaseType
  new: (@items, @opts) =>
    assert type(@items) == "table", "expected table for items in one_of"

  on_repair: (repair_fn) =>
    OneOf @items, @clone_opts repair: repair_fn

  check_value: (value) =>
    for item in *@items
      return true if item == value

      if BaseType\is_base_type(item) and item.check_value
        return true if item\check_value value

    err_strs = for i in *@items
      if type(i) == "table" and i.describe
        i\describe!
      else
        "`#{i}`"

    err_str = table.concat err_strs, ", "
    nil, "value `#{value}` did not match one of: #{err_str}"

class AllOf extends BaseType
  new: (@types, @opts) =>
    assert type(@types) == "table", "expected table for first argument"

    for checker in *@types
      assert BaseType\is_base_type(checker), "all_of expects all type checkers"

  on_repair: (repair_fn) =>
    AllOf @types, @clone_opts repair: repair_fn

  repair: (val, repair_fn) =>
    has_own_repair = @has_repair! or repair_fn

    for t in *@types
      if has_own_repair and not t\has_repair!
        continue

      res, fixed = t\repair val
      if fixed
        return res, fixed

    super val, repair_fn

  check_value: (value) =>
    for t in *@types
      pass, err = t\check_value value
      unless pass
        return nil, err

    true

class ArrayOf extends BaseType
  @type_err_message: "expecting table"

  new: (@expected, @opts) =>

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
        pass, err = @check_field shape_key, item_value, shape_val, tbl
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

  check_field: (key, value, tbl) =>
    return true if value == @expected

    if BaseType\is_base_type(@expected) and @expected.check_value
      res, err = @expected\check_value value
      unless res
        return nil, "item #{key} in array does not match: #{err}"
    else
      return nil, "item #{key} in array does not match `#{@expected}`"

    true

  check_value: (value) =>
    return nil, "expected table for array_of" unless type(value) == "table"

    for idx, item in ipairs value
      pass, err = @check_field idx, item, value
      unless pass
        return nil, err

    true

class MapOf extends BaseType
  -- TODO: this needs its own repair implementation

  new: (@expected_key, @expected_value, @opts) =>

  on_repair: (repair_fn) =>
    MapOf @expected_key, @expected_value, @clone_opts repair: repair_fn

  check_value: (value) =>
    return nil, "expected table for map_of" unless type(value) == "table"

    for k,v in pairs value
      -- check key
      if @expected_key.check_value
        res, err = @expected_key\check_value k
        unless res
          return nil, "field `#{k}` in table does not match: #{err}"

      else
        unless @expected_key == k
          return nil, "field `#{k}` does not match `#{@expected_key}`"


      -- check value
      if @expected_value.check_value
        res, err = @expected_value\check_value v
        unless res
          return nil, "field `#{k}` value in table does not match: #{err}"

      else
        unless @expected_value == v
          return nil, "field `#{k}` value does not match `#{@expected_value}`"

    true

class Shape extends BaseType
  @type_err_message: "expecting table"

  new: (@shape, @opts) =>
    assert type(@shape) == "table", "expected table for shape"

  on_repair: (repair_fn) =>
    Shape @shape, @clone_opts repair: repair_fn

  -- don't allow extra fields
  is_open: =>
    Shape @shape, @clone_opts open: true

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

  check_field: (key, value, expected_value, tbl) =>
    return true if value == expected_value

    if BaseType\is_base_type(expected_value) and expected_value.check_value
      res, err = expected_value\check_value value

      unless res
        return nil, "field `#{key}`: #{err}", err
    else
      err = "expected `#{expected_value}`, got `#{value}`"
      return nil, "field `#{key}` #{err}", err

    true

  field_errors: (value, short_circuit=false) =>
    unless type(value) == "table"
      if short_circuit
        return @@type_err_message
      else
        return { @@type_err_message }

    errors = unless short_circuit then {}

    remaining_keys = unless @opts and @opts.open
      {key, true for key in pairs value}

    for shape_key, shape_val in pairs @shape
      item_value = value[shape_key]

      if remaining_keys
        remaining_keys[shape_key] = nil

      pass, err, standalone_err = @check_field shape_key, item_value, shape_val, value
      unless pass
        if short_circuit
          return err
        else
          errors[shape_key] = standalone_err or err
          table.insert errors, err

    if remaining_keys
      if extra_key = next remaining_keys
        msg = "has extra field: `#{extra_key}`"
        if short_circuit
          return msg
        else
          return { msg }

    errors

  check_value: (value) =>
    if err = @field_errors value, true
      nil, err
    else
      true

class Pattern extends BaseType
  new: (@pattern, @opts) =>

  on_repair: (repair_fn) =>
    Pattern @pattern, @clone_opts repair: repair_fn

  describe: =>
    "pattern `#{@pattern}`"

  check_value: (value) =>
    if initial = @opts and @opts.initial_type
      return nil, "expected `#{initial}`" unless type(value) == initial

    value = tostring value if @opts and @opts.coerce

    return nil, "expected string for value" unless type(value) == "string"

    if value\match @pattern
      true
    else
      nil, "doesn't match pattern `#{@pattern}`"

class Literal extends BaseType
  new: (@value, @opts) =>

  describe: =>
    "literal `#{@t}`"

  on_repair: (repair_fn) =>
    Literal @value, @clone_opts repair: repair_fn

  check_value: (val) =>
    if @value != val
      return nil, "got `#{val}`, expected `#{@value}`"

    true

class Custom extends BaseType
  new: (@fn, @opts) =>

  describe: =>
    @opts.describe or "custom checker #{@fn}"

  on_repair: (repair_fn) =>
    Custom @fn, @clone_opts repair: repair_fn

  check_value: (val) =>
    pass, err = @.fn val, @

    unless pass
      return nil, err or "#{val} is invalid"

    true

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

  on_repair: =>
    Equivalent @val, @clone_opts repair: repair_fn

  check_value: (val) =>
    if values_equivalent @val, val
      true
    else
      nil, "#{val} is not equivalent to #{@val}"

types = setmetatable {
  any: AnyType
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

{ :check_shape, :types, :is_type, :BaseType, VERSION: "1.2.1" }
