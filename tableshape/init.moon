class BaseType
  @is_base_type: (val) =>
    cls = val and val.__class
    return false unless cls
    return true if BaseType == cls
    @is_base_type cls.__parent

  @__inherited: (cls) =>
    cls.__base.__call = cls.__call

  check_value: =>
    error "override me"

  repair: (val, fix_fn) =>
    fixed = false

    pass, err = @check_value val

    unless pass
      fix_fn or= @opts and @opts.repair
      assert fix_fn, "missing repair function for: #{err}"

      fixed = true
      val = fix_fn val, err

    val, fixed

  check_optional: (value) =>
    value == nil and @opts and @opts.optional

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

class AnyType extends BaseType
  check_value: => true
  is_optional: => AnyType

-- basic type check
class Type extends BaseType
  new: (@t, @opts) =>

  is_optional: =>
    Type @t, @clone_opts optional: true

  on_repair: (repair_fn) =>
    Type @t, @clone_opts repair: repair_fn

  check_value: (value) =>
    return true if @check_optional value

    got = type(value)
    if @t != got
      return nil, "got type `#{got}`, expected `#{@t}`"
    true

  describe: =>
    "type `#{@t}`"

class ArrayType extends BaseType
  new: (@opts) =>

  is_optional: =>
    ArrayType @clone_opts optional: true

  on_repair: (repair_fn) =>
    ArrayType @clone_opts repair: repair_fn

  check_value: (value) =>
    return true if @check_optional value
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

  is_optional: =>
    OneOf @items, @clone_opts optional: true

  on_repair: (repair_fn) =>
    OneOf @items, @clone_opts repair: repair_fn

  check_value: (value) =>
    return true if @check_optional value

    for item in *@items
      return true if item == value

      if item.check_value and BaseType\is_base_type item
        return true if item\check_value value

    err_strs = for i in *@items
      if type(i) == "table" and i.describe
        i\describe!
      else
        "`#{i}`"

    err_str = table.concat err_strs, ", "
    nil, "value `#{value}` did not match one of: #{err_str}"

class ArrayOf extends BaseType
  @type_err_message: "expecting table"

  new: (@expected, @opts) =>

  is_optional: =>
    ArrayOf @expected, @clone_opts optional: true

  on_repair: (repair_fn) =>
    ArrayOf @expected, @clone_opts repair: repair_fn

  repair: (tbl, repair_fn) =>
    return tbl, false if @check_optional tbl
    unless type(tbl) == "table"
      fix_fn or= @opts and @opts.repair
      assert fix_fn, "missing repair function for: #{@@type_err_message}"
      return fix_fn("table_invalid", @@type_err_message, tbl), true

    fixed = false
    local copy

    if @expected.repair and BaseType\is_base_type @expected
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

    if @expected.check_value and BaseType\is_base_type @expected
      res, err = @expected\check_value value
      unless res
        return nil, "item #{key} in array does not match: #{err}"
    else
      return nil, "item #{key} in array does not match `#{@expected}`"

    true

  check_value: (value) =>
    return true if @check_optional value
    return nil, "expected table for array_of" unless type(value) == "table"

    for idx, item in ipairs value
      pass, err = @check_field idx, item, value
      unless pass
        return nil, err

    true

class MapOf extends BaseType
  -- TODO: this needs its own repair implementation

  new: (@expected_key, @expected_value, @opts) =>

  is_optional: =>
    MapOf @expected_key, @expected_value, @clone_opts optional: true

  on_repair: (repair_fn) =>
    MapOf @expected_key, @expected_value, @clone_opts repair: repair_fn

  check_value: (value) =>
    return true if @check_optional value
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

  is_optional: =>
    Shape @shape, @clone_opts optional: true

  on_repair: (repair_fn) =>
    Shape @shape, @clone_opts repair: repair_fn

  -- don't allow extra fields
  is_open: =>
    Shape @shape, @clone_opts open: true

  repair: (tbl, fix_fn) =>
    return tbl, false if @check_optional tbl
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
      if shape_val.repair and BaseType\is_base_type shape_val
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
      assert fix_fn, "missing repair function for: extra field"
      for k in pairs remaining_keys
        fixed = true
        copy[k] = fix_fn "extra_field", k, copy[k]

    copy or tbl, fixed

  check_field: (key, value, expected_value, tbl) =>
    return true if value == expected_value

    if expected_value.check_value and BaseType\is_base_type expected_value
      res, err = expected_value\check_value value

      unless res
        return nil, "field `#{key}`: #{err}"
    else
      return nil, "field `#{key}` expected `#{expected_value}`"

    true

  check_value: (value) =>
    return true if @check_optional value
    return nil, @@type_err_message unless type(value) == "table"

    remaining_keys = unless @opts and @opts.open
      {key, true for key in pairs value}

    for shape_key, shape_val in pairs @shape
      item_value = value[shape_key]

      if remaining_keys
        remaining_keys[shape_key] = nil

      pass, err = @check_field shape_key, item_value, shape_val, value
      return nil, err unless pass

    if remaining_keys
      if extra_key = next remaining_keys
        return nil, "has extra field: `#{extra_key}`"

    true

class Pattern extends BaseType
  new: (@pattern, @opts) =>

  is_optional: =>
    Pattern @pattern, @clone_opts optional: true

  on_repair: (repair_fn) =>
    Pattern @pattern, @clone_opts repair: repair_fn

  describe: =>
    "pattern `#{@pattern}`"

  check_value: (value) =>
    return true if @check_optional value

    if initial = @opts and @opts.initial_type
      return nil, "expected `#{initial}`" unless type(value) == initial

    value = tostring value if @opts and @opts.coerce

    return nil, "expected string for value" unless type(value) == "string"

    if value\match @pattern
      true
    else
      nil, "doesn't match pattern `#{@pattern}`"

types = setmetatable {
  any: AnyType
  string: Type "string"
  number: Type "number"
  function: Type "function"
  func: Type "function"
  boolean: Type "boolean"
  userdata: Type "userdata"
  table: Type "table"
  array: ArrayType!

  -- compound
  integer: Pattern "^%d+$", coerce: true, initial_type: "number"

  -- type constructors
  one_of: OneOf
  shape: Shape
  pattern: Pattern
  array_of: ArrayOf
  map_of: MapOf
}, __index: (fn_name) =>
  error "Type checker does not exist: `#{fn_name}`"

check_shape = (value, shape) ->
  assert shape.check_value, "missing check_value method from shape"
  shape\check_value value

{ :check_shape, :types, :BaseType, VERSION: "1.2.0" }
