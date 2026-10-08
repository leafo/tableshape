-- JSON Schema generator for tableshape types
-- Transforms tableshape type definitions into JSON Schema objects
--
-- https://tour.json-schema.org/
--
-- The goal of this module is to get good enough, not perfectly reproduce the
-- shape. A shape author should then have a custom node to influence how the
-- json schema type is generated
--
-- this works in two passes
-- 1. simplify -> convert any complex types into their minimal type that can be serialized
-- 2. to_json_schema -> operates on common subset of types that can be directly mapped to a json schema
--
-- Both passes are plain recursive walks dispatching on the class of the type
-- object, not tableshape patterns matching over type objects: a failed one_of
-- alternative builds an error string describing the whole type tree, which
-- makes pattern based conversion of a moderate shape cost tens of milliseconds

-- TODO: detect range structure in sequences to enhance string range support

json = require "cjson"
import BaseType, types, FailedTransform from require "tableshape"

Literal = types.literal
Shape = types.shape
Partial = types.partial
ArrayOf = types.array_of
MapOf = types.map_of
OneOf = types.one_of
Range = types.range
OptionalType = types.optional
DescribeNode = types.describe
TransformNode = types._transform
AnnotateNode = types.annotate
TaggedType = types._tagged_type
TagScopeType = types._tag_scope_type
SequenceNode = types._sequence
FirstOfNode = types._first_of

-- TODO: consider using this type to wrap description/optional metadata instead of trying to pass it through state
class JsonSchema extends BaseType
  new: (@base_type, @schema) =>
    assert BaseType\is_base_type(@base_type), "expected a type checker"
    assert type(@schema) == "table" or type(@schema) == "function", "expected table or function for schema"

  _transform: (...) =>
    @base_type\_transform ...

  _describe: =>
    @base_type\_describe!

-- basic type objects and the json schema type they map to
basic_types = {
  [types.any]: "any"
  [types.string]: "string"
  [types.number]: "number"
  [types.boolean]: "boolean"
  [types.nil]: "null"
  [types.function]: "function"
  [types.table]: "object"
  [types.array]: "array"
  [types.integer]: "integer"
}

passthrough_classes = {
  [Shape]: true
  [Partial]: true
  [ArrayOf]: true
  [MapOf]: true
  [JsonSchema]: true
}

unwrap_classes = {
  [TransformNode]: "node"
  [AnnotateNode]: "base_type"
  [TaggedType]: "base_type"
  [TagScopeType]: "base_type"
}

class_of = (t) ->
  mt = getmetatable t
  mt and mt.__class

-- reduces a type to the minimal value json_schema_value can serialize, writing
-- description and optional into state in place. The second return value
-- distinguishes failure from a successful nil
local simplify
simplify = (t, state) ->
  switch type t
    when "string", "number", "boolean", "nil"
      return t, true
    when "table"
      nil
    else
      return nil, false

  if basic_types[t]
    return t, true

  cls = class_of t
  return nil, false unless cls

  if cls == Literal
    return t.value, true

  if passthrough_classes[cls]
    return t, true

  if cls == OptionalType
    state.optional = true
    return simplify t.base_type, state

  if cls == DescribeNode
    -- the outermost description wins
    state.description or= tostring t
    return simplify t.node, state

  if field = unwrap_classes[cls]
    return simplify t[field], state

  if cls == OneOf
    -- state is threaded through every option, not just the one that is used
    -- TODO: this is very basic, are there any common patterns to be extracted here?
    simplified = {}
    all_strings, all_numbers = true, true
    all_ok = true

    for opt in *t.options
      v, ok = simplify opt, state
      if ok
        if v != nil
          table.insert simplified, v
        all_strings = false if type(v) != "string"
        all_numbers = false if type(v) != "number"
      else
        all_ok = false

    if all_ok and #simplified == #t.options and (all_strings or all_numbers)
      return OneOf(simplified), true

    return (assert simplified[1], "options do not have valid type"), true

  if cls == SequenceNode
    -- TODO: this doesn't handle state merging very well
    first = nil
    for item in *t.sequence
      v, ok = simplify item, state
      if ok and v != nil and first == nil
        first = v

    return (assert first, "sequence does not have valid type"), true

  if cls == FirstOfNode
    -- types.nil + T is the optional pattern. Metadata inside T is discarded
    return nil, false unless #t.options == 2

    a, ok = simplify t.options[1], {}
    return nil, false unless ok and a == types.nil

    b, ok = simplify t.options[2], {}
    return nil, false unless ok

    state.optional = true
    return simplify b, state

  nil, false

-- state receives description and optional for the type, see simplify
local json_schema_value
json_schema_value = (t, state) ->
  v, ok = simplify t, state
  return nil, "unsupported type" unless ok

  switch type v
    when "string", "number", "boolean"
      return { const: v }, true
    when "table"
      nil
    else
      return nil, "unsupported value"

  if name = basic_types[v]
    return (if name == "any" then {} else { type: name }), true

  cls = class_of v

  if cls == JsonSchema
    schema = switch type v.schema
      when "function"
        v.schema v.base_type
      else
        v.schema

    assert type(schema) == "table", "expected table for schema"

    -- shallow copy so the caller's schema table is never mutated
    copy = {k, sv for k, sv in pairs schema}
    if mt = getmetatable schema
      setmetatable copy, mt

    return copy, true

  if cls == Literal
    return { const: v.value }, true

  if cls == OneOf
    -- simplify guarantees options are all strings or all numbers
    options = v.options
    return nil, "empty enum" if options[1] == nil

    return {
      type: type options[1]
      enum: setmetatable [o for o in *options], json.array_mt
    }, true

  if cls == Shape or cls == Partial
    properties = {}
    required = {}

    for k, field_type in pairs v.shape
      return nil, "shape key is not a string" unless type(k) == "string"

      field_state = {}
      schema, err = json_schema_value field_type, field_state
      return nil, "#{k}: #{err}" unless schema

      schema.description = field_state.description
      properties[k] = schema

      unless field_state.optional
        table.insert required, k

    table.sort required

    return {
      type: "object"
      properties: properties
      required: setmetatable required, json.array_mt
      additionalProperties: if v.open then nil else false
    }, true

  if cls == ArrayOf
    item_state = {}
    items, err = json_schema_value v.expected, item_state
    return nil, "array item: #{err}" unless items
    return nil, "array item: unexpected optional type" if item_state.optional

    local min_items, max_items
    if length_type = v.length_type
      length_state = {}
      length, ok = simplify length_type, length_state
      if ok and not length_state.optional and type(length) == "number"
        min_items, max_items = length, length
      elseif class_of(length_type) == Range
        left, left_ok = simplify length_type.left, {}
        right, right_ok = simplify length_type.right, {}
        if left_ok and right_ok and type(left) == "number" and type(right) == "number"
          min_items, max_items = left, right

    return {
      type: "array"
      items: items
      minItems: min_items
      maxItems: max_items
    }, true

  if cls == MapOf
    key_state = {}
    key, ok = simplify v.expected_key, key_state
    unless ok and not key_state.optional and key == types.string
      return nil, "map key must be string"

    value_state = {}
    value_schema, err = json_schema_value v.expected_value, value_state
    return nil, "map value: #{err}" unless value_schema
    return nil, "map value: unexpected optional type" if value_state.optional

    return {
      type: "object"
      additionalProperties: value_schema
    }, true

  nil, "unsupported type"

class ToJsonSchema extends BaseType
  _transform: (t, state) =>
    schema_state = {}
    schema, err = json_schema_value t, schema_state

    unless schema
      return FailedTransform, "could not convert to json schema: #{err}"

    if schema_state.optional
      error "unhandled optional state on type"

    schema.description = schema_state.description
    schema, state

  _describe: =>
    "json schema"

-- the exported simplify drops the metadata state
class Simplify extends BaseType
  _transform: (t, state) =>
    v, ok = simplify t, {}

    unless ok
      return FailedTransform, "could not simplify type"

    v, state

  _describe: =>
    "simplified type"

to_json_schema = ToJsonSchema!

{:to_json_schema, simplify: Simplify!, :JsonSchema}
