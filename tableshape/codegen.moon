-- tableshape.codegen: compiles a composite type object into a standalone Lua
-- function so it can be executed in optimized form.
--
-- Differences from calling _transform on the type tree directly:
--
--  * No error messages are generated. Failure is signaled by returning the
--    FailedTransform sentinel by itself, which makes testing alternatives
--    (first_of, one_of) cheap since no error strings are built for branches
--    that get discarded.
--  * types.proxy is resolved once at compile time, so the proxy function must
--    return its type when compile is called (recursion is supported, the
--    resolved type may reference the proxy again).
--  * one_of does not compare the input value against type checker options by
--    identity, it only runs the checkers.
--
-- Every node in the type tree becomes a local function in the generated
-- chunk: `tN = function(value, state) ... end`. Nodes are memoized by object
-- identity, and a node's function name is registered before its body is
-- generated so recursive types compile into direct recursive calls. Constant
-- data tables built by the compiler (one_of hashes, shape key sets) are
-- serialized directly into the source as chunk locals. Runtime values that
-- can't be serialized are passed into the chunk through the `refs` table:
-- functions, and tables that the type matches by identity (eg. a table passed
-- to types.literal), whose identity is part of their semantics. Any type
-- without a code generator
-- falls back to calling _transform on the original type object, so arbitrary
-- types can always be compiled.
--
-- Purity: a node is pure when it can neither transform the value nor change
-- the state (eg. plain validation with no transforms or tags). Pure subtrees
-- compile to inline boolean expressions instead of function calls, and pure
-- container types (shape, array_of, map_of) skip all of the copy-on-write
-- machinery: they allocate nothing and return the input value untouched.
--
-- Extending: custom types (BaseType subclasses) are compilable as-is via the
-- _transform fallback, but they can opt into optimized compilation by
-- implementing any of the following:
--
--  _compile_pure: boolean field, or (compiler) => pure[, provisional]
--    Declare that the type never changes the value or state. Wrapper types
--    can delegate with compiler\is_pure. Types without this are assumed
--    impure, which disables the pure fast paths of any containing type.
--
--  _compile_predicate: (compiler, value_expr, state_expr) => lua_expr
--    Return a lua expression (a string) that is truthy iff the value held in
--    value_expr matches. Used to inline the check into parent types. Must be
--    side effect free and is only consulted for pure types. Return nil to
--    fall back to a compiled function call.
--
--  _compile_transform: (compiler, emit) => nil
--    Emit the statements (one per emit call) for the body of the type's
--    generated `function(value, state)`. The body must return the
--    transformed value & state on success, or the local FailedTransform by
--    itself on failure, without mutating anything on the failure path and
--    without building error messages. Falling off the end of the body fails
--    the type.
--
--  _compile_inner: => inner_type
--    Declare the type a transparent wrapper (eg. one that only changes error
--    messages): it compiles directly to the returned inner type. All other
--    codegen hooks on the type are ignored.
--
-- Compiler methods available to implementations:
--
--  compiler\ref(val) -> name           close over a runtime value
--  compiler\value_expr(val) -> expr    serialize a primitive (or ref it)
--  compiler\const(val) -> name         serialize a data table into a chunk
--                                      local (or ref it)
--  compiler\compile_node(t) -> name    compile a child type, get its fn name
--  compiler\predicate_expr(t, v, s)    boolean expression for a child type
--  compiler\is_pure(t) -> bool         purity of a child type

import types, BaseType, FailedTransform from require "tableshape"

load_code = loadstring or load

-- must match the behavior of clone_state in tableshape.init, which is not
-- exported from the module
clone_state = (state_obj) ->
  if type(state_obj) != "table"
    return {}

  out = {k, v for k, v in pairs state_obj}

  if mt = getmetatable state_obj
    setmetatable out, mt

  out

-- iterate a table in a deterministic order (sorted by key type, then key
-- value) so the same schema always generates identical source
sorted_pairs = (t) ->
  keys = [k for k in pairs t]

  table.sort keys, (a, b) ->
    ta, tb = type(a), type(b)
    if ta != tb
      ta < tb
    else
      switch ta
        when "number", "string"
          a < b
        when "boolean"
          not a and b
        else
          -- no cross-run order exists for these (eg. table keys), but at
          -- least keep the order consistent within this process
          tostring(a) < tostring(b)

  i = 0
  ->
    i += 1
    k = keys[i]
    unless k == nil
      k, t[k]

-- many of the classes are not exported from tableshape.init, so they are
-- extracted from the instances & constructors held in the types table
Type = types.string.__class
AnyType = types.any.__class
ArrayType = types.array.__class
CloneType = types.clone.__class
NotType = (-types.any).__class

Literal = types.literal
OneOf = types.one_of
AllOf = types.all_of
Shape = types.shape
Partial = types.partial
Pattern = types.pattern
ArrayOf = types.array_of
ArrayContains = types.array_contains
MapOf = types.map_of
Range = types.range
Custom = types.custom
TagScopeType = types.scope
Proxy = types.proxy
AnnotateNode = types.annotate
DescribeNode = types.describe
OptionalType = types.optional
TransformNode = types._transform
TaggedType = types._tagged_type
SequenceNode = types._sequence
FirstOfNode = types._first_of

class Compiler
  -- dispatched on the exact class of the node. Subclasses of these types may
  -- override methods in ways codegen can't see, so they take the _transform
  -- fallback instead
  handlers: {
    [AnyType]: "compile_any"
    [Literal]: "compile_literal"
    [Type]: "compile_type"
    [OneOf]: "compile_one_of"
    [AllOf]: "compile_all_of"
    [SequenceNode]: "compile_sequence"
    [FirstOfNode]: "compile_first_of"
    [TransformNode]: "compile_transform"
    [OptionalType]: "compile_optional"
    [NotType]: "compile_not"
    [TaggedType]: "compile_tagged"
    [TagScopeType]: "compile_scope"
    [Shape]: "compile_shape"
    [Partial]: "compile_shape"
    [ArrayType]: "compile_array"
    [ArrayOf]: "compile_array_of"
    [ArrayContains]: "compile_array_contains"
    [MapOf]: "compile_map_of"
    [Range]: "compile_range"
    [Pattern]: "compile_pattern"
    [Custom]: "compile_custom"
    [CloneType]: "compile_clone"
    [Proxy]: "compile_proxy"
  }

  new: (opts) =>
    @lines = {}
    @refs = {}
    @ref_ids = {}
    @consts = {}
    @const_ids = {}
    @fn_ids = {}
    @fn_count = 0
    @pure_cache = {}
    @pure_active = {}
    @proxy_cache = {}
    @node_stack = {}

    if opts
      @static = opts.static and true

  push: (line) => table.insert @lines, line

  -- the description of the node currently being compiled, for diagnostics
  current_node_description: =>
    node = @node_stack[#@node_stack]
    unless node
      return "<unknown type>"

    ok, description = pcall -> node\_describe!
    if ok and description
      description
    else
      tostring node

  -- register a runtime value to be passed into the generated chunk, returns
  -- the name of the local that will hold it. In static mode this is a
  -- compile error: the generated code would depend on a value that can't be
  -- represented in source
  ref: (val) =>
    if @static
      error "static compile: #{@current_node_description!} requires a runtime reference (#{tostring val})"

    name = @ref_ids[val]
    unless name
      table.insert @refs, val
      name = "r#{#@refs}"
      @ref_ids[val] = name

    name

  -- serialize a number into a lua expression that reproduces it exactly,
  -- returns nil if one can't be found
  number_expr: (val) =>
    if val != val -- nan
      return "(0/0)"

    if val == math.huge
      return "math.huge"

    if val == -math.huge
      return "-math.huge"

    s = tostring val
    if tonumber(s) == val
      return s

    -- tostring truncates precision on some floats, 17 significant digits
    -- always round trips a double
    s = ("%.17g")\format val
    if tonumber(s) == val
      return s

  -- serialize a value into a lua expression, falling back to a reference for
  -- values that can't be represented in source. NOTE: tables always become
  -- references, never constructors: type checkers match table values by
  -- identity, which a fresh table built in source could never satisfy
  value_expr: (val) =>
    switch type val
      when "string"
        ("%q")\format val
      when "boolean", "nil"
        tostring val
      when "number"
        @number_expr(val) or @ref val
      else
        @ref val

  -- serialize a plain data table (no metatable, acyclic, only primitive or
  -- nested data table keys & values) into a table constructor expression.
  -- Returns nil for tables that can't be fully represented in source
  data_expr: (val, seen={}) =>
    return nil if getmetatable val
    return nil if seen[val]
    seen[val] = true

    parts = {}

    array_len = 0
    for i, item in ipairs val
      expr = @data_item_expr item, seen
      return nil unless expr
      table.insert parts, expr
      array_len = i

    for k, v in sorted_pairs val
      continue if type(k) == "number" and k >= 1 and k <= array_len and k % 1 == 0

      key = @data_item_expr k, seen
      return nil unless key

      item = @data_item_expr v, seen
      return nil unless item

      table.insert parts, "[#{key}] = #{item}"

    seen[val] = nil
    "{#{table.concat parts, ", "}}"

  data_item_expr: (val, seen) =>
    switch type val
      when "string"
        ("%q")\format val
      when "boolean"
        tostring val
      when "number"
        @number_expr val
      when "table"
        @data_expr val, seen

  -- register a constant data table to be emitted as a local in the generated
  -- chunk, returns the name of the local. Only for tables whose identity
  -- doesn't matter (lookup tables built by the compiler). Falls back to a
  -- runtime reference when the table can't be serialized
  const: (val) =>
    name = @const_ids[val]
    unless name
      expr = @data_expr val
      unless expr
        return @ref val

      table.insert @consts, expr
      name = "c#{#@consts}"
      @const_ids[val] = name

    name

  resolve_proxy: (node) =>
    inner = @proxy_cache[node]
    unless inner
      inner = assert node.fn!, "proxy missing transformer"
      @proxy_cache[node] = inner

    inner

  -- a node is pure when transforming can neither change the value nor the
  -- state: it either fails or passes the input through untouched. Returns
  -- purity, and whether the result depended on an in-progress node (a
  -- recursive type), meaning it can't be cached
  is_pure: (node) =>
    cached = @pure_cache[node]
    if cached != nil
      return cached, false

    if @pure_active[node]
      -- optimistic assumption for recursive types: any impurity elsewhere in
      -- the cycle still forces the final result to false
      return true, true

    @pure_active[node] = true
    result, provisional = @compute_pure node
    @pure_active[node] = nil

    -- a provisionally true result may be invalidated by impurity in another
    -- branch of the cycle that produced it, so it can't be cached
    if not provisional or result == false
      @pure_cache[node] = result

    result, provisional

  -- check purity of a list that may mix type checkers and literal values.
  -- literals are always pure
  all_pure: (nodes) =>
    provisional = false
    for n in *nodes
      continue unless BaseType\is_base_type n
      p, prov = @is_pure n

      unless p
        return false, false

      if prov
        provisional = true

    true, provisional

  compute_pure: (node) =>
    if node._compile_inner
      return @is_pure node\_compile_inner!

    -- types can declare their own purity through the codegen protocol
    custom = node._compile_pure
    if custom != nil
      if type(custom) == "function"
        result, provisional = node\_compile_pure @
        return (result and true or false), (provisional and true or false)
      else
        return (custom and true or false), false

    switch node.__class
      when AnyType, Literal, Range, Custom, ArrayType
        true, false
      when Pattern
        -- a coerce type only produces the test value, the input passes
        -- through untouched
        true, false
      when NotType
        -- always restores the original value & state, even over an impure
        -- inner type
        true, false
      when Type
        if node.length_type
          @is_pure node.length_type
        else
          true, false
      when OneOf
        if node.options_hash
          true, false
        else
          @all_pure node.options
      when AllOf
        @all_pure node.types
      when SequenceNode
        @all_pure node.sequence
      when FirstOfNode
        @all_pure node.options
      when OptionalType
        @is_pure node.base_type
      when DescribeNode
        @is_pure node.node
      when AnnotateNode
        @is_pure node.base_type
      when Shape, Partial
        children = [v for _, v in pairs node.shape]
        if node.extra_fields_type
          table.insert children, node.extra_fields_type
        @all_pure children
      when ArrayOf
        children = { node.expected }
        if node.length_type
          table.insert children, node.length_type
        @all_pure children
      when ArrayContains
        @all_pure { node.contains }
      when MapOf
        @all_pure { node.expected_key, node.expected_value }
      when Proxy
        @is_pure @resolve_proxy node
      else
        -- transforms, tags, clone, and unknown types are assumed impure
        false, false

  -- a boolean expression testing if the pure node matches the value held in
  -- expression v (with current state in variable s). Returns nil when the
  -- node has no inline representation. Only valid for pure nodes
  inline_predicate: (node, v, s) =>
    table.insert @node_stack, node
    result = @build_inline_predicate node, v, s
    table.remove @node_stack
    result

  build_inline_predicate: (node, v, s) =>
    if node._compile_inner
      return @inline_predicate node\_compile_inner!, v, s

    if node._compile_predicate
      return node\_compile_predicate @, v, s

    switch node.__class
      when AnyType
        "true"
      when Literal
        "#{v} == #{@value_expr node.value}"
      when Type
        base = "type(#{v}) == #{@value_expr node.t}"
        if node.length_type
          "#{base} and #{@predicate_expr node.length_type, "##{v}", s}"
        else
          base
      when Range
        vt = @value_expr node.value_type.t
        "type(#{v}) == #{vt} and #{v} >= #{@value_expr node.left} and #{v} <= #{@value_expr node.right}"
      when Pattern
        pat = @value_expr node.pattern
        if node.coerce
          unless BaseType\is_base_type node.coerce
            "string_match(tostring(#{v}), #{pat}) ~= nil"
          -- coercing through a type needs statements, no inline form
        else
          "(type(#{v}) == 'string' and string_match(#{v}, #{pat}) ~= nil)"
      when Custom
        "(#{@ref node.fn}(#{v}, #{s}))"
      when OneOf
        if node.options_hash
          "#{@const node.options_hash}[#{v}] ~= nil"
        else
          if #node.options == 0
            return "false"

          parts = for option in *node.options
            if BaseType\is_base_type option
              "(#{@predicate_expr option, v, s})"
            else
              "#{v} == #{@value_expr option}"

          "(#{table.concat parts, " or "})"
      when FirstOfNode
        if #node.options == 0
          return "false"

        parts = ["(#{@predicate_expr option, v, s})" for option in *node.options]
        "(#{table.concat parts, " or "})"
      when SequenceNode
        if #node.sequence == 0
          return "true"

        parts = ["(#{@predicate_expr child, v, s})" for child in *node.sequence]
        "(#{table.concat parts, " and "})"
      when AllOf
        if #node.types == 0
          return "true"

        parts = ["(#{@predicate_expr child, v, s})" for child in *node.types]
        "(#{table.concat parts, " and "})"
      when NotType
        -- valid even for an impure inner type: its value/state results are
        -- discarded either way
        "not (#{@predicate_expr node.base_type, v, s})"
      when OptionalType
        "(#{v} == nil or (#{@predicate_expr node.base_type, v, s}))"
      when DescribeNode
        @inline_predicate node.node, v, s
      when AnnotateNode
        @inline_predicate node.base_type, v, s

  -- like inline_predicate but always produces an expression, falling back to
  -- calling the node's compiled function. Callers must discard value/state
  -- results (ie. the node is pure, or results are thrown away like in not)
  predicate_expr: (node, v, s) =>
    if pred = @inline_predicate node, v, s
      pred
    else
      "(#{@compile_node node}(#{v}, #{s})) ~= FailedTransform"

  -- compile a node into a function in the generated chunk, returns the name
  -- of the function. Results are memoized on the node object
  compile_node: (node) =>
    if name = @fn_ids[node]
      return name

    cls = node.__class

    -- transparent wrapper types compile directly to their inner type
    if node._compile_inner
      name = @compile_node node\_compile_inner!
      @fn_ids[node] = name
      return name

    -- nodes that only affect error messages compile directly to their inner
    -- type
    if cls == DescribeNode
      name = @compile_node node.node
      @fn_ids[node] = name
      return name

    if cls == AnnotateNode
      name = @compile_node node.base_type
      @fn_ids[node] = name
      return name

    @fn_count += 1
    name = "t#{@fn_count}"

    -- registered before generating the body so recursive references resolve
    -- to this function
    @fn_ids[node] = name

    buffer = {}
    emit = (line) -> table.insert buffer, line

    table.insert @node_stack, node

    inline = if @is_pure node
      @inline_predicate node, "value", "state"

    if inline
      emit "if #{inline} then return value, state end"
      emit "return FailedTransform"
    elseif node._compile_transform
      -- the body is wrapped so falling off the end fails the type instead of
      -- silently returning nil (which would read as a successful transform)
      emit "do"
      node\_compile_transform @, emit
      emit "end"
      emit "return FailedTransform"
    else
      handler_name = @handlers[cls]
      handler = if handler_name
        @[handler_name]
      else
        @compile_fallback

      handler @, node, emit

    table.remove @node_stack

    @push "#{name} = function(value, state)"
    for line in *buffer
      @push line
    @push "end"

    name

  assemble: (main_name) =>
    buf = {
      "local FailedTransform, clone_state, refs = ..."
      "local type, pairs, ipairs, next, tostring = type, pairs, ipairs, next, tostring"
      "local getmetatable, setmetatable = getmetatable, setmetatable"
      "local string_match = string.match"
    }

    if #@refs > 0
      names = table.concat ["r#{i}" for i=1,#@refs], ", "
      exprs = table.concat ["refs[#{i}]" for i=1,#@refs], ", "
      table.insert buf, "local #{names} = #{exprs}"

    for i, expr in ipairs @consts
      table.insert buf, "local c#{i} = #{expr}"

    if @fn_count > 0
      table.insert buf, "local " .. table.concat ["t#{i}" for i=1,@fn_count], ", "

    for line in *@lines
      table.insert buf, line

    table.insert buf, "return #{main_name}"
    table.concat(buf, "\n") .. "\n"

  -- calls _transform on the original type object for nodes that don't have a
  -- code generator
  compile_fallback: (node, emit) =>
    emit "local v, s = #{@ref node}:_transform(value, state)"
    emit "if v == FailedTransform then return FailedTransform end"
    emit "return v, s"

  -- NOTE: many simple types (any, literal, range, custom, pure one_of, ...)
  -- are always handled by the inline predicate path in compile_node. Their
  -- handlers below are kept for completeness. Handlers are reached when the
  -- node is impure or has no inline form

  compile_any: (node, emit) =>
    emit "return value, state"

  compile_literal: (node, emit) =>
    emit "if value ~= #{@value_expr node.value} then return FailedTransform end"
    emit "return value, state"

  -- reached when length_type is impure
  compile_type: (node, emit) =>
    emit "if type(value) ~= #{@value_expr node.t} then return FailedTransform end"

    if node.length_type
      fn = @compile_node node.length_type
      emit "local lv, ls = #{fn}(#value, state)"
      emit "if lv == FailedTransform then return FailedTransform end"
      emit "return value, ls"
    else
      emit "return value, state"

  compile_one_of: (node, emit) =>
    if node.options_hash
      emit "if #{@const node.options_hash}[value] then return value, state end"
      emit "return FailedTransform"
      return

    for option in *node.options
      if BaseType\is_base_type option
        if @is_pure option
          emit "if #{@predicate_expr option, "value", "state"} then return value, state end"
        else
          fn = @compile_node option
          emit "do"
          emit "local v, s = #{fn}(value, state)"
          emit "if v ~= FailedTransform then return v, s end"
          emit "end"
      else
        emit "if value == #{@value_expr option} then return value, state end"

    emit "return FailedTransform"

  -- shared by compile_all_of & compile_sequence
  compile_sequence_children: (children, emit) =>
    emit "local v, s = value, state"
    for child in *children
      if @is_pure child
        emit "if not (#{@predicate_expr child, "v", "s"}) then return FailedTransform end"
      else
        fn = @compile_node child
        emit "v, s = #{fn}(v, s)"
        emit "if v == FailedTransform then return FailedTransform end"
    emit "return v, s"

  compile_all_of: (node, emit) =>
    @compile_sequence_children node.types, emit

  compile_sequence: (node, emit) =>
    @compile_sequence_children node.sequence, emit

  compile_first_of: (node, emit) =>
    for option in *node.options
      if @is_pure option
        emit "if #{@predicate_expr option, "value", "state"} then return value, state end"
      else
        fn = @compile_node option
        emit "do"
        emit "local v, s = #{fn}(value, state)"
        emit "if v ~= FailedTransform then return v, s end"
        emit "end"

    emit "return FailedTransform"

  compile_transform: (node, emit) =>
    if @is_pure node.node
      emit "if not (#{@predicate_expr node.node, "value", "state"}) then return FailedTransform end"
      emit "local v, s = value, state"
    else
      fn = @compile_node node.node
      emit "local v, s = #{fn}(value, state)"
      emit "if v == FailedTransform then return FailedTransform end"

    if type(node.t_fn) == "function"
      t_ref = @ref node.t_fn
      if node.with_state
        emit "return #{t_ref}(v, s), s"
      else
        emit "return #{t_ref}(v), s"
    else
      emit "return #{@value_expr node.t_fn}, s"

  -- reached when base_type is impure
  compile_optional: (node, emit) =>
    emit "if value == nil then return value, state end"
    emit "return #{@compile_node node.base_type}(value, state)"

  compile_not: (node, emit) =>
    emit "local v = #{@compile_node node.base_type}(value, state)"
    emit "if v == FailedTransform then return value, state end"
    emit "return FailedTransform"

  -- shared by compile_tagged & compile_scope: emit the state update for a
  -- string (or string array) tag
  emit_set_tag: (emit, state_name, key, value_name, tag_array) =>
    if tag_array
      emit "local existing = #{state_name}[#{key}]"
      emit "if type(existing) == 'table' then"
      emit "local copy = {}"
      emit "for ek, ev in pairs(existing) do copy[ek] = ev end"
      emit "copy[#copy + 1] = #{value_name}"
      emit "#{state_name}[#{key}] = copy"
      emit "else"
      emit "#{state_name}[#{key}] = { #{value_name} }"
      emit "end"
    else
      emit "#{state_name}[#{key}] = #{value_name}"

  compile_tagged: (node, emit) =>
    if @is_pure node.base_type
      emit "if not (#{@predicate_expr node.base_type, "value", "state"}) then return FailedTransform end"
      emit "local v, s = value, clone_state(state)"
    else
      fn = @compile_node node.base_type
      emit "local v, s = #{fn}(value, state)"
      emit "if v == FailedTransform then return FailedTransform end"
      emit "s = clone_state(s)"

    if node.tag_type == "function"
      emit "#{@ref node.tag_name}(s, v)"
    else
      @emit_set_tag emit, "s", @value_expr(node.tag_name), "v", node.tag_array

    emit "return v, s"

  compile_scope: (node, emit) =>
    fn = @compile_node node.base_type
    -- scopes start with a fresh state
    emit "local v, scope = #{fn}(value, nil)"
    emit "if v == FailedTransform then return FailedTransform end"

    if node.tag_name
      emit "state = clone_state(state)"

      if node.tag_type == "function"
        emit "#{@ref node.tag_name}(state, v, scope)"
      else
        @emit_set_tag emit, "state", @value_expr(node.tag_name), "scope", node.tag_array

    emit "return v, state"

  compile_shape: (node, emit) =>
    emit "if type(value) ~= 'table' then return FailedTransform end"

    -- constant set of the shape's own keys, used to detect extra fields
    -- without allocating a scratch table per call
    shape_keys = {k, true for k in pairs node.shape}

    if @is_pure node
      -- nothing can transform: check fields in place, never build an output
      -- table
      for shape_key, shape_val in sorted_pairs node.shape
        key = @value_expr shape_key
        emit "do"
        emit "local item = value[#{key}]"

        if BaseType\is_base_type shape_val
          emit "if not (#{@predicate_expr shape_val, "item", "state"}) then return FailedTransform end"
        else
          emit "if item ~= #{@value_expr shape_val} then return FailedTransform end"

        emit "end"

      unless node.open
        keys_ref = @const shape_keys
        if node.extra_fields_type
          emit "for rk in pairs(value) do"
          emit "if #{keys_ref}[rk] == nil then"
          emit "local tuple_in = {[rk] = value[rk]}"
          emit "if not (#{@predicate_expr node.extra_fields_type, "tuple_in", "state"}) then return FailedTransform end"
          emit "end"
          emit "end"
        else
          emit "for rk in pairs(value) do"
          emit "if #{keys_ref}[rk] == nil then return FailedTransform end"
          emit "end"

      emit "return value, state"
      return

    emit "local dirty = false"
    emit "local out = {}"

    for shape_key, shape_val in sorted_pairs node.shape
      key = @value_expr shape_key
      emit "do"
      emit "local item = value[#{key}]"

      if BaseType\is_base_type shape_val
        if @is_pure shape_val
          emit "if not (#{@predicate_expr shape_val, "item", "state"}) then return FailedTransform end"
          emit "out[#{key}] = item"
        else
          fn = @compile_node shape_val
          emit "local v, s = #{fn}(item, state)"
          emit "if v == FailedTransform then return FailedTransform end"
          emit "state = s"
          emit "if v ~= item then dirty = true end"
          emit "out[#{key}] = v"
      else
        emit "if item ~= #{@value_expr shape_val} then return FailedTransform end"
        emit "out[#{key}] = item"

      emit "end"

    keys_ref = @const shape_keys
    if node.open
      emit "for rk in pairs(value) do"
      emit "if #{keys_ref}[rk] == nil then out[rk] = value[rk] end"
      emit "end"
    elseif node.extra_fields_type
      fn = @compile_node node.extra_fields_type
      emit "for rk in pairs(value) do"
      emit "if #{keys_ref}[rk] == nil then"
      emit "local item = value[rk]"
      emit "local tuple, s = #{fn}({[rk] = item}, state)"
      emit "if tuple == FailedTransform then return FailedTransform end"
      emit "state = s"
      emit "local nk = tuple and next(tuple)"
      emit "if nk == nil then"
      emit "dirty = true"
      emit "else"
      emit "if nk ~= rk or tuple[nk] ~= item then dirty = true end"
      emit "out[nk] = tuple[nk]"
      emit "end"
      emit "end"
      emit "end"
    else
      emit "for rk in pairs(value) do"
      emit "if #{keys_ref}[rk] == nil then return FailedTransform end"
      emit "end"

    emit "if dirty then return out, state end"
    emit "return value, state"

  compile_array: (node, emit) =>
    emit "if type(value) ~= 'table' then return FailedTransform end"
    emit "local k = 1"
    emit "for i in pairs(value) do"
    emit "if type(i) ~= 'number' then return FailedTransform end"
    emit "if i ~= k then return FailedTransform end"
    emit "k = k + 1"
    emit "end"
    emit "return value, state"

  compile_array_of: (node, emit) =>
    emit "if type(value) ~= 'table' then return FailedTransform end"
    expected = node.expected

    if @is_pure node
      -- nothing can transform or update state: check items in place
      if node.length_type
        emit "local len = #value"
        emit "if not (#{@predicate_expr node.length_type, "len", "state"}) then return FailedTransform end"

      emit "for _, item in ipairs(value) do"
      if BaseType\is_base_type expected
        emit "if not (#{@predicate_expr expected, "item", "state"}) then return FailedTransform end"
      else
        emit "if item ~= #{@value_expr expected} then return FailedTransform end"
      emit "end"
      emit "return value, state"
      return

    if node.length_type
      fn = @compile_node node.length_type
      emit "do"
      emit "local lv, ls = #{fn}(#value, state)"
      emit "if lv == FailedTransform then return FailedTransform end"
      emit "state = ls"
      emit "end"

    if BaseType\is_base_type expected
      if @is_pure expected
        -- only the length check was impure
        emit "for _, item in ipairs(value) do"
        emit "if not (#{@predicate_expr expected, "item", "state"}) then return FailedTransform end"
        emit "end"
        emit "return value, state"
        return

      fn = @compile_node expected
      emit "local copy, ci"
      emit "for idx, item in ipairs(value) do"
      emit "local skip = false"
      emit "local v, s = #{fn}(item, state)"
      emit "if v == FailedTransform then return FailedTransform end"
      emit "state = s"

      unless node.keep_nils
        emit "if v == nil then skip = true end"

      emit "if skip or v ~= item then"
      emit "if not copy then"
      emit "copy = {}"
      emit "for pi = 1, idx - 1 do copy[pi] = value[pi] end"
      emit "ci = idx"
      emit "end"
      emit "end"
      emit "if copy and not skip then"
      emit "copy[ci] = v"
      emit "ci = ci + 1"
      emit "end"
      emit "end"
      emit "return copy or value, state"
    else
      emit "for idx, item in ipairs(value) do"
      emit "if item ~= #{@value_expr expected} then return FailedTransform end"
      emit "end"
      emit "return value, state"

  compile_array_contains: (node, emit) =>
    emit "if type(value) ~= 'table' then return FailedTransform end"

    if @is_pure node
      -- no transforms possible, so the result is the input value as soon as
      -- a match is found, regardless of short_circuit
      cond = if BaseType\is_base_type node.contains
        @predicate_expr node.contains, "item", "state"
      else
        "item == #{@value_expr node.contains}"

      emit "for _, item in ipairs(value) do"
      emit "if #{cond} then return value, state end"
      emit "end"
      emit "return FailedTransform"
      return

    emit "local contains = false"
    emit "local copy, ci"
    emit "for idx, item in ipairs(value) do"
    emit "local skip = false"
    emit "local transformed = item"

    if BaseType\is_base_type node.contains
      fn = @compile_node node.contains
      emit "local v, s = #{fn}(item, state)"
      emit "if v ~= FailedTransform then"
      emit "state = s"
      emit "contains = true"
      if node.keep_nils
        emit "transformed = v"
      else
        emit "if v == nil then skip = true else transformed = v end"
      emit "end"
    else
      emit "if item == #{@value_expr node.contains} then contains = true end"

    emit "if skip or transformed ~= item then"
    emit "if not copy then"
    emit "copy = {}"
    emit "for pi = 1, idx - 1 do copy[pi] = value[pi] end"
    emit "ci = idx"
    emit "end"
    emit "end"
    emit "if copy and not skip then"
    emit "copy[ci] = transformed"
    emit "ci = ci + 1"
    emit "end"

    if node.short_circuit
      emit "if contains then"
      emit "if copy then"
      emit "for ri = idx + 1, #value do"
      emit "copy[ci] = value[ri]"
      emit "ci = ci + 1"
      emit "end"
      emit "end"
      emit "break"
      emit "end"

    emit "end"
    emit "if not contains then return FailedTransform end"
    emit "return copy or value, state"

  compile_map_of: (node, emit) =>
    emit "if type(value) ~= 'table' then return FailedTransform end"

    -- note: MapOf coerces literal arguments into types in its constructor,
    -- but handle literals anyway in case the fields were assigned directly
    emit_pair_check = (expected, var_name) ->
      if BaseType\is_base_type expected
        if @is_pure expected
          emit "if not (#{@predicate_expr expected, var_name, "state"}) then return FailedTransform end"
          return false -- var not reassigned
        else
          fn = @compile_node expected
          emit "do"
          emit "local s"
          emit "new_#{var_name}, s = #{fn}(#{var_name}, state)"
          emit "if new_#{var_name} == FailedTransform then return FailedTransform end"
          emit "state = s"
          emit "end"
          return true
      else
        emit "if #{var_name} ~= #{@value_expr expected} then return FailedTransform end"
        return false

    if @is_pure node
      emit "for mk, mv in pairs(value) do"
      emit_pair_check node.expected_key, "mk"
      emit_pair_check node.expected_value, "mv"
      emit "end"
      emit "return value, state"
      return

    emit "local transformed = false"
    emit "local out = {}"
    emit "for mk, mv in pairs(value) do"
    emit "local new_mk, new_mv = mk, mv"
    emit_pair_check node.expected_key, "mk"
    emit_pair_check node.expected_value, "mv"
    emit "if new_mk ~= mk or new_mv ~= mv then transformed = true end"
    emit "if new_mk ~= nil then out[new_mk] = new_mv end"
    emit "end"
    emit "if transformed then return out, state end"
    emit "return value, state"

  compile_range: (node, emit) =>
    emit "if type(value) ~= #{@value_expr node.value_type.t} then return FailedTransform end"
    emit "if value < #{@value_expr node.left} or value > #{@value_expr node.right} then return FailedTransform end"
    emit "return value, state"

  -- reached when coerce is a type checker
  compile_pattern: (node, emit) =>
    if node.coerce
      if BaseType\is_base_type node.coerce
        fn = @compile_node node.coerce
        emit "local test = #{fn}(value, nil)"
        emit "if test == FailedTransform then return FailedTransform end"
      else
        emit "local test = tostring(value)"
    else
      emit "local test = value"

    emit "if type(test) ~= 'string' then return FailedTransform end"
    emit "if not string_match(test, #{@value_expr node.pattern}) then return FailedTransform end"
    emit "return value, state"

  compile_custom: (node, emit) =>
    emit "if not #{@ref node.fn}(value, state) then return FailedTransform end"
    emit "return value, state"

  compile_clone: (node, emit) =>
    emit "local vt = type(value)"
    emit "if vt == 'table' then"
    emit "local copy = {}"
    emit "for ck, cv in pairs(value) do copy[ck] = cv end"
    emit "local mt = getmetatable(value)"
    emit "if mt then setmetatable(copy, mt) end"
    emit "return copy, state"
    emit "elseif vt == 'nil' or vt == 'string' or vt == 'number' or vt == 'boolean' then"
    emit "return value, state"
    emit "end"
    emit "return FailedTransform"

  compile_proxy: (node, emit) =>
    -- the proxy function is resolved once, at compile time
    fn = @compile_node @resolve_proxy node
    emit "return #{fn}(value, state)"

-- the wrapper type returned by compile. Behaves like any other type checker
-- (check_value, transform, operators, etc.) but runs the generated function.
-- The raw compiled function is available as the `fn` field for callers that
-- want to skip method dispatch entirely
class CompiledType extends BaseType
  new: (@node, @fn, @code, opts) =>
    if opts
      @rerun_errors = opts.rerun_errors and true

  -- error messages are not generated by compiled code: a single generic one
  -- is built from the source type's description and cached
  build_error: =>
    unless @error_message
      ok, description = pcall -> @node\_describe!
      @error_message = if ok
        "expected #{description}"
      else
        "failed to match compiled type"

    @error_message

  -- with rerun_errors, the interpreted type is run on failure to produce its
  -- exact error message (or errors object): failures pay for an extra
  -- interpreted pass, successes stay on the compiled path
  fail_error: (value, state) =>
    if @rerun_errors
      result, err = @node\_transform value, state

      -- if the interpreted type disagrees with the compiled result (eg. a
      -- custom function that isn't deterministic), don't return its
      -- success state as an error
      if result == FailedTransform
        return err

    @build_error!

  _transform: (value, state) =>
    new_value, new_state = @.fn value, state

    if new_value == FailedTransform
      return FailedTransform, @fail_error value, state

    new_value, new_state

  -- check_value & transform are overridden to call the compiled function
  -- directly, skipping a layer of dispatch
  check_value: (value, state) =>
    v, s = @.fn value, state

    if v == FailedTransform
      return nil, @fail_error value, state

    if type(s) == "table"
      s
    else
      true

  transform: (value, state) =>
    v, s = @.fn value, state

    if v == FailedTransform
      return nil, @fail_error value, state

    if type(s) == "table"
      v, s
    else
      v

  repair: (...) => @transform ...

  _describe: =>
    @node\_describe!

-- generate the lua source for a type checker, returns the code string and
-- the array of refs that must be passed into the loaded chunk
-- opts:
--  static: error instead of creating a runtime reference, guaranteeing the
--    generated code is self-contained source (refs is always empty)
generate_code = (node, opts) ->
  assert BaseType\is_base_type(node), "expected type checker to compile"
  compiler = Compiler opts
  main_name = compiler\compile_node node
  compiler\assemble(main_name), compiler.refs

-- opts:
--  rerun_errors: on failure, run the original interpreted type to produce
--    its full error message or errors object instead of a generic one
--  static: see generate_code
compile = (node, opts) ->
  code, refs = generate_code node, opts
  chunk = assert load_code code, "tableshape.codegen"
  fn = chunk FailedTransform, clone_state, refs
  CompiledType node, fn, code, opts

{ :compile, :generate_code, :CompiledType, :Compiler }
