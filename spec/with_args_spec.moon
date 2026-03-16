import types from require "tableshape"
import with_args from require "tableshape.ext.with_args"

describe "tableshape.with_args", ->
  it "validates basic arguments", ->
    wrapped_fn = with_args {
      types.number
      types.string
    }, (a, b) -> "#{a}-#{b}"

    assert.same {
      "42-hello"
    }, { wrapped_fn 42, "hello" }

  it "returns error for invalid arguments with assert: false", ->
    wrapped_fn = with_args {
      types.number
      types.string
    }, (a, b) -> "#{a}-#{b}"

    assert.same {
      nil
      'argument 1: expected type "number", got "string"'
    }, { wrapped_fn "not a number", "hello" }

    assert.same {
      nil
      'argument 2: expected type "string", got "number"'
    }, { wrapped_fn 42, 123 }

  it "throws error with assert: true", ->
    wrapped_fn = with_args {
      assert: true
      types.number
      types.string
    }, (a, b) -> "#{a}-#{b}"

    -- This should work fine
    assert.same "42-hello", wrapped_fn 42, "hello"

    -- This should throw an error
    assert.has_error ->
      wrapped_fn "not a number", "hello"

  it "handles rest arguments", ->
    wrapped_fn = with_args {
      rest: types.string
      types.number
    }, (first, ...) ->
      rest_args = {...}
      "first=#{first}, rest=#{table.concat rest_args, ','}"

    assert.same {
      "first=42, rest=hello,world"
    }, { wrapped_fn 42, "hello", "world" }

  it "validates rest arguments", ->
    wrapped_fn = with_args {
      rest: types.string
      types.number
    }, (first, ...) -> "ok"

    assert.same {
      nil
      'argument 2 (rest): expected type "string", got "number"'
    }, { wrapped_fn 42, 123 }

  it "transforms arguments", ->
    wrapped_fn = with_args {
      types.number / (n) -> n * 2
      types.string / string.upper
    }, (a, b) -> "#{a}-#{b}"

    assert.same {
      "10-HELLO"
    }, { wrapped_fn 5, "hello" }

  it "handles literal argument types", ->
    wrapped_fn = with_args {
      42
      "expected"
    }, (a, b) -> "#{a}-#{b}"

    assert.same {
      "42-expected"
    }, { wrapped_fn 42, "expected" }

    assert.same {
      nil
      'argument 1: expected 42'
    }, { wrapped_fn "wrong", "expected" }

  it "passes through extra arguments when no rest type specified", ->
    wrapped_fn = with_args {
      types.number
    }, (...) ->
      args = {...}
      table.concat [tostring(arg) for arg in *args], ","

    assert.same {
      "42,hello,world"
    }, { wrapped_fn 42, "hello", "world" }

  it "handles no arguments", ->
    wrapped_fn = with_args {}, -> "no args"

    assert.same {
      "no args"
    }, { wrapped_fn! }

  it "validates complex types", ->
    wrapped_fn = with_args {
      types.shape {
        name: types.string
        age: types.number
      }
    }, (person) -> "#{person.name} is #{person.age}"

    assert.same {
      "John is 30"
    }, { wrapped_fn { name: "John", age: 30 } }

    assert.same {
      nil
      'argument 1: field "age": expected type "number", got "string"'
    }, { wrapped_fn { name: "John", age: "thirty" } }

  it "returns error for missing arguments (fewer than expected)", ->
    wrapped_fn = with_args {
      types.number
      types.string
    }, (a, b) -> "#{a}-#{b}"

    assert.same {
      nil
      'argument 2: expected type "string", got "nil"'
    }, { wrapped_fn 42 }

  it "allows nil for optional argument types", ->
    wrapped_fn = with_args {
      types.number
      types.string\is_optional!
    }, (a, b) -> "a=#{a}, b=#{tostring b}"

    assert.same { "a=42, b=nil" }, { wrapped_fn 42, nil }

  it "handles assert: false explicitly", ->
    wrapped_fn = with_args {
      assert: false
      types.number
    }, (a) -> a * 2

    assert.same { 84 }, { wrapped_fn 42 }
    assert.same {
      nil
      'argument 1: expected type "number", got "string"'
    }, { wrapped_fn "bad" }

  it "validates rest with literal type", ->
    wrapped_fn = with_args {
      rest: "ok"
      types.number
    }, (first, ...) ->
      rest_args = {...}
      "first=#{first}, rest=#{table.concat rest_args, ','}"

    assert.same {
      "first=42, rest=ok,ok"
    }, { wrapped_fn 42, "ok", "ok" }

    assert.same {
      nil
      'argument 3 (rest): expected "ok"'
    }, { wrapped_fn 42, "ok", "bad" }

  it "transforms rest arguments", ->
    wrapped_fn = with_args {
      rest: types.string / string.upper
      types.number
    }, (first, ...) ->
      rest_args = {...}
      "first=#{first}, rest=#{table.concat rest_args, ','}"

    assert.same {
      "first=42, rest=HELLO,WORLD"
    }, { wrapped_fn 42, "hello", "world" }

  it "throws on invalid rest arguments with assert: true", ->
    wrapped_fn = with_args {
      assert: true
      rest: types.string
      types.number
    }, (first, ...) -> "ok"

    assert.same "ok", wrapped_fn 42, "hello"

    assert.has_error (->
      wrapped_fn 42, 123
    ), 'argument 2 (rest): expected type "string", got "number"'

  it "handles no extra args when rest is specified", ->
    wrapped_fn = with_args {
      rest: types.string
      types.number
    }, (first, ...) ->
      rest_args = {...}
      "first=#{first}, count=#{#rest_args}"

    assert.same {
      "first=42, count=0"
    }, { wrapped_fn 42 }

  it "preserves multiple return values", ->
    wrapped_fn = with_args {
      types.number
    }, (a) -> a, a * 2, "extra"

    assert.same { 5, 10, "extra" }, { wrapped_fn 5 }

  it "handles wrapped function returning nil", ->
    wrapped_fn = with_args {
      types.number
    }, (a) -> nil

    assert.same 1, select "#", wrapped_fn 5
    assert.is_nil (wrapped_fn 5)

  it "errors on invalid first argument to with_args", ->
    assert.has_error (->
      with_args "not a table", ->
    ), "with_args expects table for first argument"

  it "errors on invalid second argument to with_args", ->
    assert.has_error (->
      with_args {}, "not a function"
    ), "with_args expects function for second argument"