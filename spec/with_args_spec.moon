import types, with_args from require "tableshape"

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