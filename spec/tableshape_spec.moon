
{check_shape: check, :types} = require "tableshape"

describe "tableshape", ->
  basic_types = {
    {"any", valid: 1234}
    {"any", valid: "hello"}
    {"any", valid: ->}
    {"any", valid: true}
    {"any", valid: nil}

    {"number", valid: 1234, invalid: "hello"}
    {"function", valid: (->), invalid: {}}
    {"string", valid: "234", invalid: 777}
    {"boolean", valid: true, invalid: 24323}

    {"table", valid: { hi: "world" }, invalid: "{}"}
    {"array", valid: { 1,2,3,4 }, invalid: {hi: "yeah"}, check_errors: false}
    {"array", valid: {}, check_errors: false}

    {"integer", valid: 1234, invalid: 1.1}
    {"integer", valid: 0, invalid: "1243"}
  }

  for {type_name, :valid, :invalid, :check_errors} in *basic_types
    it "tests #{type_name}", ->
      t = types[type_name]

      assert.same {true}, {check valid, t}

      if invalid
        failure = {check invalid, t}
        if check_errors
          assert.same {nil, "got type #{type invalid}, expected #{type_name}"}, failure
        else
          assert.nil failure[1]

        failure = {check nil, t}
        if check_errors
          assert.same {nil, "got type nil, expected #{type_name}"}, failure
        else
          assert.nil failure[1]

      -- optional
      t = t\is_optional!
      assert.same {true}, {check valid, t}

      if invalid
        failure = {check invalid, t}
        if check_errors
          assert.same {nil, "got type #{type invalid}, expected #{type_name}"}, failure
        else
          assert.nil failure[1]

        assert.same {true}, {check nil, t}

  it "tests one_of", ->
    ab = types.one_of {"a", "b"}
    ab_opt = ab\is_optional!

    assert.same nil, (ab "c")
    assert.same true, (ab "a")
    assert.same true, (ab "b")
    assert.same nil, (ab nil)

    assert.same nil, (ab_opt "c")
    assert.same true, (ab_opt "a")
    assert.same true, (ab_opt "b")
    assert.same true, (ab_opt nil)

    -- with sub type checkers
    misc = types.one_of { "g", types.number, types.function }

    assert.same nil, (misc "c")
    assert.same true, (misc 2354)
    assert.same true, (misc ->)
    assert.same true, (misc "g")
    assert.same nil, (misc nil)

  it "tests shape", ->
    check = types.shape { color: "red" }
    assert.same nil, (check color: "blue")
    assert.same true, (check color: "red")

    check = types.shape {
      color: types.one_of {"red", "blue"}
      weight: types.number
    }

    -- correct
    assert.same {true}, {
      check {
        color: "blue"
        weight: 234
      }
    }

    -- failed sub type
    assert.same nil, (
      check {
        color: "green"
        weight: 234
      }
    )

    -- missing data
    assert.same nil, (
      check {
        color: "green"
      }
    )

    -- extra data
    assert.same {true}, {
      check\is_open! {
        color: "red"
        weight: 9
        age: 3
      }
    }

    -- extra data
    assert.same nil, (
      check {
        color: "red"
        weight: 9
        age: 3
      }
    )

  it "tests pattern", ->
    t = types.pattern "^hello"

    assert.same nil, (t 123)
    assert.same {true}, {t "hellowolr"}
    assert.same nil, (t "hell")

    t = types.pattern "^%d+$", coerce: true

    assert.same {true}, {t 123}
    assert.same {true}, {t "123"}
    assert.same nil, (t "2.5")


  it "tests map_of", ->
    stringmap = types.map_of types.string, types.string
    assert.same {true}, {stringmap {}}

    assert.same {true}, {stringmap {
      hello: "world"
    }}

    assert.same {true}, {stringmap {
      hello: "world"
      butt: "zone"
    }}

    assert.same {true}, {stringmap\is_optional! nil}
    assert.same nil, (stringmap nil)

    assert.same nil, (stringmap { hello: 5 })
    assert.same nil, (stringmap { "okay" })
    assert.same nil, (stringmap { -> })

    static = types.map_of "hello", "world"
    assert.same {true}, {static {}}
    assert.same {true}, {static { hello: "world" }}

    assert.same nil, (static { helloz: "world" })
    assert.same nil, (static { hello: "worldz" })

  it "tests array_of", ->
    numbers = types.array_of types.number

    assert.same {true}, {numbers {}}
    assert.same {true}, {numbers {1}}
    assert.same {true}, {numbers {1.5}}
    assert.same {true}, {numbers {1.5,2,3,4}}

    assert.same {true}, {numbers\is_optional! nil}
    assert.same nil, (numbers nil)

    hellos = types.array_of "hello"

    assert.same {true}, {hellos {}}
    assert.same {true}, {hellos {"hello"}}
    assert.same {true}, {hellos {"hello", "hello"}}

    assert.same nil, (hellos {"hello", "world"})

    shapes = types.array_of types.shape {
      color: types.one_of {"orange", "blue"}
    }

    assert.same {true}, {
      shapes {
        {color: "orange"}
        {color: "blue"}
        {color: "orange"}
      }
    }

    assert.same nil, (
      shapes {
        {color: "orange"}
        {color: "blue"}
        {color: "purple"}
      }
    )

