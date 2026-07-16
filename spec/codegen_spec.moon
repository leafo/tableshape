import types, BaseType, FailedTransform from require "tableshape"
import compile, generate_code, generate_module, CompiledType from require "tableshape.codegen"

-- runs both the interpreted and compiled type on input and asserts the same
-- outcome. Error messages are not compared since compiled types don't
-- generate them
assert_parity = (t, compiled, input) ->
  expected_v, expected_s = t\_transform input
  got_v, got_s = compiled\_transform input

  if expected_v == FailedTransform
    assert.equal FailedTransform, got_v, "compiled type should have failed"
  else
    assert.same expected_v, got_v
    assert.same expected_s, got_s

    -- when the interpreted type passes the input table through untouched,
    -- the compiled type should return the exact same table
    if type(expected_v) == "table" and rawequal(expected_v, input)
      assert rawequal(got_v, input), "compiled type should return input table unmodified"

describe "tableshape.codegen", ->
  basic_inputs = {
    "hello", "", "123", "5", 0, 5, -1.5, math.huge, -math.huge, true, false,
    {}, {1,2,3}, {"one", "two"}, {a: 1, b: 2}, {1, 2, a: "b"},
    {name: "lee", age: 7}, print
  }

  test_parity = (name, t) ->
    it name, ->
      compiled = compile t
      assert_parity t, compiled, nil
      for input in *basic_inputs
        assert_parity t, compiled, input

  describe "parity with interpreted types", ->
    parity_types = {
      "any": types.any
      "string": types.string
      "number": types.number
      "boolean": types.boolean
      "table": types.table
      "function": types.func
      "nil": types["nil"]
      "array": types.array
      "integer": types.integer
      "clone": types.clone

      "literal string": types.literal "hello"
      "literal number": types.literal 5
      "literal boolean": types.literal true
      "literal infinity": types.literal math.huge
      "literal negative infinity": types.literal(-math.huge)
      "range with infinity": types.range -math.huge, math.huge

      "string with length": types.string\length 2, 5
      "one_of hash": types.one_of {"a", "hello", 5}
      "one_of mixed": types.one_of {"a", types.number, types.literal true}
      "first_of": types.literal(55) + types.string + types.array
      "sequence": types.string * types.pattern "^h"
      "all_of": types.all_of {types.table, types.array}
      "not": -types.string
      "optional": types.string\is_optional!
      "describe": types.number\describe "a number"
      "annotate": types.annotate types.string
      "range": types.range 1, 10
      "range string": types.range "a", "f"
      "pattern": types.pattern "^%d+$"
      "custom": types.custom (v) -> type(v) == "table"
      "equivalent (fallback)": types.equivalent {1, 2, {3}}

      "transform": types.string / (s) -> "<#{s}>"
      "transform constant": types.string / "CONST"
      "transform to nil": types.string / nil

      "array_of": types.array_of types.number
      "array_of literal": types.array_of "one"
      "array_of transform": types.array_of types.number / (n) -> n + 1
      "array_of with length": types.array_of types.any, length: types.range(2, 3)
      "array_of strip nils": types.array_of types.number + (types.any / nil)
      "array_of keep nils": types.array_of types.number + (types.any / nil), keep_nils: true

      "array_contains": types.array_contains types.string
      "array_contains literal": types.array_contains 2
      "array_contains transform": types.array_contains types.number / (n) -> n * 10
      "array_contains no short circuit": types.array_contains (types.number / (n) -> n * 10), short_circuit: false

      "map_of": types.map_of types.string, types.any
      "map_of literal": types.map_of "a", 1
      "map_of transform": types.map_of types.string, types.number / (n) -> n + 1

      "shape": types.shape { name: types.string, age: types.number }
      "shape literal values": types.shape { name: "lee", age: types.number }
      "shape open": types.shape { name: types.string }, open: true
      "shape check_all": types.shape { name: types.string, age: types.number }, check_all: true
      "shape extra_fields": types.shape { name: types.string }, extra_fields: types.map_of(types.string, types.any)
      "shape extra_fields transform key": types.shape { name: types.string }, extra_fields: types.map_of(types.string / (s) -> "x_#{s}", types.any)
      "shape extra_fields strip": types.shape { name: types.string }, extra_fields: types.any / nil
      "partial": types.partial { name: types.string }
      "shape transform": types.shape { name: types.string / (s) -> s\upper!, age: types.number }

      -- mixed pure/impure compositions
      "one_of with transform": types.one_of {"a", types.number / (n) -> n + 1}
      "first_of mixed": (types.number / (n) -> n + 1) + types.string
      "sequence mixed": types.table * (types.any / (v) -> v) * types.table
      "not over transform": -(types.string / (s) -> "#{s}!")
      "optional transform": (types.string / (s) -> "#{s}!")\is_optional!
      "array_of impure length": types.array_of types.string, length: types.range(1, 3)\tag "len"
      "map_of key transform": types.map_of (types.string / (s) -> "k_#{s}"), types.any
      "shape extra_fields tagged": types.shape { name: types.string }, extra_fields: types.any\tag "extras[]"
    }

    for name, t in pairs parity_types
      test_parity name, t

  describe "generated code", ->
    it "returns loadable source and refs", ->
      code, refs = generate_code types.shape {
        name: types.string
        tags: types.array_of types.string\tag "tags[]"
      }

      assert.is_string code
      assert.is_table refs
      loader = loadstring or load
      assert loader code

    it "rejects non type values", ->
      assert.has_error ->
        generate_code "not a type"

    it "compiles pure types without output tables", ->
      code = generate_code types.shape {
        name: types.string
        age: types.number
        tags: types.array_of types.string
        role: types.one_of {"admin", "user"}
      }

      -- a pure shape never transforms, so it should not allocate an output
      -- table or track dirtiness
      assert.is_nil code\find("local out", 1, true), "pure shape should not build an output table"
      assert.is_nil code\find("dirty", 1, true), "pure shape should not track dirty state"

    it "serializes compiler lookup tables instead of passing refs", ->
      -- the one_of options hash and the shape's key set are constant data,
      -- so this type needs no runtime values at all
      code, refs = generate_code types.shape {
        name: types.string
        role: types.one_of {"admin", "user", 5}
      }

      assert.same {}, refs

    it "serializes floats that tostring truncates", ->
      value = 0.1 + 0.2

      code, refs = generate_code types.literal value
      assert.same {}, refs

      compiled = compile types.literal value
      assert.is_true compiled\check_value value
      assert.is_nil (compiled\check_value 0.3)

    it "generates deterministic output", ->
      -- separately constructed but equal schemas must generate byte
      -- identical source, so generated files can be committed without churn
      build = -> types.shape {
        gamma: types.string / "x"
        alpha: types.number\tag "a"
        beta: types.boolean
        delta: types.one_of {"on", "off"}
        [1]: types.string
        [true]: types.string
      }

      assert.same (generate_code build!), (generate_code build!)

      -- fields are emitted in sorted key order
      code = generate_code build!
      positions = for key in *{"alpha", "beta", "delta", "gamma"}
        (assert code\find('value["' .. key .. '"]', 1, true), "missing field #{key}")

      for i = 2, #positions
        assert positions[i - 1] < positions[i], "fields not emitted in sorted order"

    it "passes table literals as refs to preserve identity matching", ->
      tbl = {1, 2}
      t = types.literal tbl
      compiled = compile t

      code, refs = generate_code t
      assert.same {tbl}, refs

      -- interpreted literal matches tables by identity, so a structurally
      -- equal table must not match
      assert.is_true compiled\check_value tbl
      assert.is_nil (compiled\check_value {1, 2})
      assert_parity t, compiled, tbl
      assert_parity t, compiled, {1, 2}

  describe "static mode", ->
    it "generates self-contained code", ->
      code, refs = generate_code types.shape({
        name: types.string
        role: types.one_of {"admin", "user"}
        age: types.range 0, 150
        email: types.pattern "^[^@]+@[^@]+$"
        title: types.string / "CONST"
      }), static: true

      assert.same {}, refs

      compiled = compile types.shape({ name: types.string }), static: true
      assert.is_true compiled\check_value { name: "lee" }

    it "rejects types that need runtime references", ->
      cases = {
        "custom checker": types.custom (v) -> true
        "transform function": types.string / (s) -> s
        "function tag": types.string\tag (state, v) -> nil
        "table literal": types.literal {1, 2}
        "fallback type": types.equivalent {1, 2}
      }

      for name, t in pairs cases
        ok, err = pcall generate_code, t, static: true
        assert.is_false ok, "#{name} should fail static compile"
        assert err\find("requires a runtime reference", 1, true), "#{name}: #{err}"

    it "names the offending type in the error", ->
      -- the custom checker is pure and inlined into the shape, but the
      -- error should point at the checker, not the whole shape
      t = types.shape {
        count: types.custom (v) -> type(v) == "number"
      }

      ok, err = pcall generate_code, t, static: true
      assert.is_false ok
      assert err\find("custom checker", 1, true), err

  describe "generate_module", ->
    load_module = (code) ->
      loader = loadstring or load
      chunk = assert loader code
      chunk!

    it "generates a standalone module", ->
      t = types.shape {
        name: types.string
        age: types.range 0, 150
        role: types.one_of {"admin", "user"}
        id: types.number\tag "id"
      }

      code = generate_module t

      -- self contained: no imports, no runtime references
      assert.is_nil code\find("require", 1, true)
      assert.is_nil code\find("%.%.%."), "module should not expect chunk arguments"

      m = load_module code

      input = { name: "lee", age: 7, role: "admin", id: 5 }
      assert.same { id: 5 }, m.check_value input
      assert.same t\check_value(input), m.check_value input

      v, err = m.check_value { name: 5 }
      assert.is_nil v
      assert.is_string err
      assert err\find("expected", 1, true), err

    it "transforms values with state", ->
      t = types.shape {
        title: types.string / "renamed"
        id: types.number\tag "id"
      }

      m = load_module generate_module t

      out, state = m.transform { title: "original", id: 9 }
      assert.same { title: "renamed", id: 9 }, out
      assert.same { id: 9 }, state

      -- repair is an alias for transform
      assert.equal m.transform, m.repair

    it "omits clone_state when the type has no tags", ->
      code = generate_module types.shape { name: types.string }
      assert.is_nil code\find("clone_state", 1, true)

      tagged = generate_module types.shape { name: types.string\tag "n" }
      assert tagged\find("clone_state", 1, true), "tagged module should include clone_state"

    it "rejects types that can't compile statically", ->
      assert.has_error ->
        generate_module types.custom (v) -> true

  describe "transforms", ->
    it "matches deterministic shape transform order", ->
      counter = types.any % (value, state) ->
        state.count += 1
        state.count

      t = types.shape {
        zeta: counter
        alpha: counter
        gamma: counter
      }

      input = { zeta: 0, alpha: 0, gamma: 0 }
      expected_value, expected_state = t\transform input, count: 0
      value, state = (compile t)\transform input, count: 0

      assert.same { alpha: 1, gamma: 2, zeta: 3 }, value
      assert.same expected_value, value
      assert.same expected_state, state

    it "matches deterministic extra field order", ->
      t = types.shape {}, extra_fields: types.map_of(types.any, types.any\tag "values[]")
      input = { zeta: "z", alpha: "a", middle: "m" }

      assert_parity t, compile(t), input
      assert.same { values: { "a", "m", "z" } }, (compile(t))\check_value input

    it "matches deterministic map_of order", ->
      t = types.map_of types.any, types.any\tag "values[]"
      input = { zeta: "z", alpha: "a", middle: "m" }

      assert_parity t, compile(t), input
      assert.same { values: { "a", "m", "z" } }, (compile(t))\check_value input

    it "visits pure types in interpreted order for map_of and extra fields", ->
      -- a pure type (custom) still has an observable body, so the compiled
      -- loop must visit keys in the same order the interpreter does
      order = {}
      rec = types.custom (v) ->
        table.insert order, v
        true

      input = { zeta: "z", alpha: "a", middle: "m" }

      record_order = (t) ->
        order = {}
        t\check_value input
        [v for v in *order]

      for t in *{
        types.map_of types.string, rec
        types.shape {}, extra_fields: types.map_of types.string, rec
      }
        assert.same (record_order t), (record_order compile t)

    it "transforms values", ->
      compiled = compile types.string / (s) -> "--#{s}--"
      assert.same "--hello--", (compiled\transform "hello")
      assert.is_nil (compiled\transform 5)

    it "returns fresh table when transformed, same table when not", ->
      t = types.array_of types.string + (types.number / (n) -> n * 2)
      compiled = compile t

      input = {"a", "b"}
      out = compiled\transform input
      assert rawequal(input, out), "untransformed input should pass through"

      input2 = {"a", 5}
      out2 = compiled\transform input2
      assert.same {"a", 10}, out2
      assert not rawequal(input2, out2), "transformed input should be a copy"
      assert.same {"a", 5}, input2, "input should not be mutated"

    it "transforms with state", ->
      t = types.shape({ id: types.number\tag "id" }) % (val, state) -> state.id
      compiled = compile t
      assert.same 5, (compiled\transform { id: 5 })

  describe "tags", ->
    it "collects named tags", ->
      t = types.shape {
        types.number\tag "first"
        types.string\tag "second"
      }

      compiled = compile t
      assert.same { first: 5, second: "hey" }, compiled\check_value { 5, "hey" }
      assert_parity t, compiled, { 5, "hey" }
      assert_parity t, compiled, { "wrong", 5 }

    it "collects array tags", ->
      t = types.array_of types.number\tag "nums[]"
      compiled = compile t
      assert.same { nums: {1, 2, 3} }, compiled\check_value {1, 2, 3}
      assert_parity t, compiled, {1, 2, 3}
      assert_parity t, compiled, {1, "no", 3}

    it "calls function tags", ->
      t = types.array_of types.number\tag (state, val) ->
        state.sum = (state.sum or 0) + val

      compiled = compile t
      assert.same { sum: 6 }, compiled\check_value {1, 2, 3}

    it "does not mutate state on failed branches", ->
      t = types.shape({ types.number\tag("a"), types.literal("x") }) + types.shape({ types.number\tag("b"), types.literal("y") })
      compiled = compile t

      assert.same { b: 9 }, compiled\check_value { 9, "y" }
      assert_parity t, compiled, { 9, "y" }

    it "handles scoped tags", ->
      t = types.array_of types.scope types.shape({ types.number\tag "n" }), tag: "items[]"
      compiled = compile t
      assert.same { items: { {n: 1}, {n: 2} } }, compiled\check_value { {1}, {2} }
      assert_parity t, compiled, { {1}, {2} }
      assert_parity t, compiled, { {"x"} }

    it "handles function scope tags", ->
      t = types.array_of types.scope types.shape({ types.number\tag "n" }), tag: (state, val, scope) ->
        state.total = (state.total or 0) + scope.n

      compiled = compile t
      assert.same { total: 3 }, compiled\check_value { {1}, {2} }

  describe "recursion", ->
    it "compiles recursive types via proxy", ->
      local node_type
      node_type = types.shape {
        value: types.number
        children: types.array_of types.proxy -> node_type
      }

      compiled = compile node_type

      good = {
        value: 1
        children: {
          { value: 2, children: {} }
          { value: 3, children: { { value: 4, children: {} } } }
        }
      }

      bad = {
        value: 1
        children: { { value: "x", children: {} } }
      }

      assert.is_true compiled\check_value good
      assert.is_nil (compiled\check_value bad)

      assert_parity node_type, compiled, good
      assert_parity node_type, compiled, bad

    it "transforms through recursive types", ->
      local tree
      tree = types.shape {
        value: types.number / (n) -> n * 2
        children: types.array_of types.proxy -> tree
      }

      compiled = compile tree

      input = { value: 1, children: { { value: 2, children: {} } } }
      assert.same {
        value: 2
        children: { { value: 4, children: {} } }
      }, (compiled\transform input)

      assert_parity tree, compiled, input

  describe "fallback", ->
    it "falls back to _transform for unsupported types", ->
      class Doubler extends BaseType
        _transform: (value, state) =>
          if type(value) == "number"
            return value * 2, state
          FailedTransform, "expected number"

        _describe: => "doubler"

      t = types.shape { x: Doubler! }
      compiled = compile t

      assert.same { x: 10 }, (compiled\transform { x: 5 })
      assert.is_nil (compiled\transform { x: "no" })

  describe "moonscript types", ->
    mtypes = require "tableshape.moonscript"

    class Animal
    class Dog extends Animal
    class Cat extends Animal
    class Poodle extends Dog

    -- classes, instances, base tables, and impostors
    ms_inputs = {
      Animal, Dog, Cat, Poodle
      Animal!, Dog!, Cat!, Poodle!
      Animal.__base
      {}, {__base: {}}, setmetatable({}, {})
      "hello", 5, true, print
    }

    check_ms_parity = (t) ->
      compiled = compile t
      assert_parity t, compiled, nil
      for input in *ms_inputs
        assert_parity t, compiled, input
      compiled

    it "class_type parity", ->
      check_ms_parity mtypes.class_type

    it "instance_type parity", ->
      check_ms_parity mtypes.instance_type

    it "instance_of parity", ->
      check_ms_parity mtypes.instance_of Animal
      check_ms_parity mtypes.instance_of Dog
      check_ms_parity mtypes.instance_of "Animal"
      check_ms_parity mtypes.instance_of "Dog"
      check_ms_parity mtypes.instance_of "Missing"

    it "subclass_of parity", ->
      check_ms_parity mtypes.subclass_of Animal
      check_ms_parity mtypes.subclass_of Dog
      check_ms_parity mtypes.subclass_of "Animal"
      check_ms_parity mtypes.subclass_of Animal, allow_same: true
      check_ms_parity mtypes.subclass_of "Dog", allow_same: true

    it "compiles as pure inline predicates", ->
      compiled = compile types.shape { pet: mtypes.instance_of Animal }

      -- no fallback to the interpreted type, and the containing shape stays
      -- on the pure fast path
      assert.is_nil compiled.code\find(":_transform", 1, true)
      assert.is_nil compiled.code\find("local out", 1, true)

      assert.is_true compiled\check_value { pet: Dog! }
      assert.is_true compiled\check_value { pet: Poodle! }
      assert.is_nil (compiled\check_value { pet: Animal })
      assert.is_nil (compiled\check_value { pet: {} })

  describe "codegen protocol", ->
    it "inlines custom types that provide a predicate", ->
      class Even extends BaseType
        _describe: => "even number"

        _transform: (value, state) =>
          if type(value) == "number" and value % 2 == 0
            return value, state
          FailedTransform, "expected even number"

        _compile_pure: true
        _compile_predicate: (compiler, v, s) =>
          "(type(#{v}) == 'number' and #{v} % 2 == 0)"

      t = types.shape { n: Even! }
      compiled = compile t

      assert.is_true compiled\check_value { n: 4 }
      assert.is_nil (compiled\check_value { n: 5 })
      assert.is_nil (compiled\check_value { n: "x" })

      -- the check was inlined: no fallback call to the type object, and the
      -- shape stayed on the pure fast path
      assert.is_nil compiled.code\find("_transform", 1, true)
      assert.is_nil compiled.code\find("local out", 1, true)

    it "compiles custom types that provide a transform body", ->
      class Halve extends BaseType
        _describe: => "halvable number"

        _transform: (value, state) =>
          if type(value) == "number"
            return value / 2, state
          FailedTransform, "expected number"

        _compile_transform: (compiler, emit) =>
          emit "if type(value) ~= 'number' then return FailedTransform end"
          emit "return value / 2, state"

      t = types.shape { x: Halve! }
      compiled = compile t

      assert.same { x: 5 }, (compiled\transform { x: 10 })
      assert.is_nil (compiled\transform { x: "no" })
      assert.is_nil compiled.code\find("_transform", 1, true)
      assert_parity t, compiled, { x: 10 }
      assert_parity t, compiled, { x: false }

    it "fails safely when a transform body falls through", ->
      class Forgetful extends BaseType
        _describe: => "forgetful"
        _transform: (value, state) =>
          if value == "yes"
            return value, state
          FailedTransform, "expected yes"

        _compile_transform: (compiler, emit) =>
          emit "if value == 'yes' then return value, state end"
          -- forgot to emit the failure return

      compiled = compile Forgetful!
      assert.is_true compiled\check_value "yes"
      assert.is_nil (compiled\check_value "no")

    it "supports wrapper types that delegate through compiler helpers", ->
      class Wrapped extends BaseType
        new: (@base) =>
        _describe: => "wrapped #{@base\_describe!}"
        _transform: (value, state) => @base\_transform value, state

        _compile_pure: (compiler) => compiler\is_pure @base
        _compile_predicate: (compiler, v, s) => compiler\predicate_expr @base, v, s
        _compile_transform: (compiler, emit) =>
          emit "return #{compiler\compile_node @base}(value, state)"

      -- pure base: inlines, no function call or fallback
      pure = compile types.shape { name: Wrapped types.string }
      assert.is_true pure\check_value { name: "hi" }
      assert.is_nil (pure\check_value { name: 5 })
      assert.is_nil pure.code\find("local out", 1, true)

      -- impure base: compiles through _compile_transform
      impure = compile Wrapped types.string / (s) -> s\upper!
      assert.same "HI", (impure\transform "hi")
      assert.is_nil (impure\transform 5)
      assert.is_nil impure.code\find("_transform", 1, true)

    it "compiles transparent wrappers via _compile_inner", ->
      -- a type that only reformats error messages, like a flatten_errors
      class NoteErrors extends BaseType
        new: (@base) =>
        _describe: => @base\_describe!
        _compile_inner: => @base

        _transform: (value, state) =>
          new_value, state_or_err = @base\_transform value, state
          if new_value == FailedTransform
            return FailedTransform, "noted: #{state_or_err}"
          new_value, state_or_err

      t = types.shape { name: NoteErrors types.string }
      compiled = compile t

      assert.is_true compiled\check_value { name: "hi" }
      assert.is_nil (compiled\check_value { name: 5 })

      -- the wrapper disappeared: the inner type inlined and the shape stayed
      -- on the pure fast path
      assert.is_nil compiled.code\find("_transform", 1, true)
      assert.is_nil compiled.code\find("local out", 1, true)

  describe "CompiledType", ->
    it "acts like a type checker", ->
      compiled = compile types.string

      assert.is_true compiled "hello" -- __call
      assert.is_nil (compiled 5)
      assert.same "world", (compiled\transform "world")
      assert.same 'type "string"', compiled\_describe!

    it "generates an error message on failure", ->
      compiled = compile types.number\describe "a number"
      v, err = compiled\check_value "x"
      assert.is_nil v
      assert.same "expected a number", err

    it "reruns the interpreted type for exact errors when requested", ->
      t = types.shape { name: types.string, age: types.number }
      compiled = compile t, rerun_errors: true

      input = { name: 5, age: 7 }
      expected_v, expected_err = t\check_value input
      v, err = compiled\check_value input

      assert.is_nil expected_v
      assert.is_nil v
      assert.same expected_err, err

      -- error objects (non string errors) pass through unchanged
      class TableErrors extends BaseType
        _describe: => "table errors"
        _transform: (value, state) =>
          if value == "ok"
            return value, state
          FailedTransform, {"first error", "second error"}

      compiled_errs = compile TableErrors!, rerun_errors: true
      v, errs = compiled_errs\check_value "bad"
      assert.is_nil v
      assert.same {"first error", "second error"}, errs
      assert.is_true compiled_errs\check_value "ok"

    it "rerun falls back to generic error if interpreted type disagrees", ->
      -- a nondeterministic type: fails on the first call, passes after
      calls = 0
      class Flaky extends BaseType
        _describe: => "flaky"
        _transform: (value, state) =>
          calls += 1
          if calls == 1
            return FailedTransform, "flaky error"
          value, state

      compiled = compile Flaky!, rerun_errors: true
      v, err = compiled\check_value "x"
      assert.is_nil v
      -- the rerun passed, so the success state must not leak out as an error
      assert.same "expected flaky", err

    it "can be composed with regular types", ->
      compiled = compile types.number
      t = types.shape { x: compiled / (n) -> n + 1 }
      assert.same { x: 6 }, (t\transform { x: 5 })

    it "can itself be compiled", ->
      compiled = compile compile types.number
      assert.is_true compiled 5
      assert.is_nil (compiled "no")
