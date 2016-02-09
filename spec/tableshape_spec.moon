
{check_shape: check, :types} = require "tableshape"

deep_copy = (v) ->
  if type(v) == "table"
    {k, deep_copy(v) for k,v in pairs v}
  else
    v

test_examples = (t_fn, examples) ->
  for id, {:input, :expected, :fails} in ipairs examples
    it "repairs object #{id}", ->
      t = t_fn!

      clone = deep_copy input
      if fails
        assert.has_error ->
          out, fixed = t\repair input
      else
        out, fixed = t\repair input

        if expected
          assert.same true, fixed
          assert.same expected, out
        else
          assert.true out == input
          assert.same false, fixed

      -- the repair didn't mutate original table
      assert.same clone, input


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

    more = types.one_of {true, 123}
    assert.same nil, (more "c")
    assert.same nil, (more false)
    assert.same nil, (more 124)
    assert.same true, (more 123)
    assert.same true, (more true)

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

  it "tests shape with literals", ->
    check = types.shape {
      color: "green"
      weight: 123
      ready: true
    }

    assert.same nil, (
      check {
        color: "greenz"
        weight: 123
        ready: true
      }
    )

    assert.same nil, (
      check {
        color: "greenz"
        weight: 125
        ready: true
      }
    )

    assert.same nil, (
      check {
        color: "greenz"
        weight: 125
        ready: false
      }
    )

    assert.same nil, (
      check {
        free: true
      }
    )

    assert.same true, (
      check {
        color: "green"
        weight: 123
        ready: true
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

    twothreefours = types.array_of 234

    assert.same {true}, {twothreefours {}}
    assert.same {true}, {twothreefours {234}}
    assert.same {true}, {twothreefours {234, 234}}
    assert.same nil, (twothreefours {"uh"})

  describe "repair", ->
    it "doesn't repair basic type", ->
      assert.same {
        "hi", false
      }, {
        types.string\repair "hi", (val, err) -> tostring val
      }

    it "repairs a basic type", ->
      assert.same {
        "2334232", true
      }, {
        types.string\repair 2334232, (val, err) -> tostring val
      }

    it "repairs using repair option callback", ->
      int_string = types.pattern "^%d+$", {
        optional: true
        repair: (str) =>
          "0"
      }

      assert.same { "123", false }, { int_string\repair "123" }
      assert.same { "0", true }, { int_string\repair "what" }
      assert.same { nil, false }, { int_string\repair nil }

    it "repairs shape with repairable field", ->
      int_string = types.pattern "^%d+$", repair: (str, err) ->
        assert.same "zone", str
        assert.same "doesn't match pattern `^%d+$`", err
        "0"

      t = types.shape {
        hello: int_string
      }

      assert.same { {hello: "0"}, true }, { t\repair { hello: "zone" } }
      assert.same { {hello: "123"}, false }, { t\repair { hello: "123" } }

    it "repairs shape with shape's repair func on plain field", ->
      t = types.shape({
        hello: "world"
      })\on_repair (msg, key, val, err, expected_val) ->
        assert.same "field_invalid", msg
        assert.same "hello", key
        assert.same "zone", val
        assert.same "world", expected_val
        assert.same "field `hello` expected `world`, got `zone`", err
        "world"

      assert.same { { hello: "world" }, true }, { t\repair { hello: "zone" } }

    it "repairs shape with shape's repair function when type is wrong", ->
      t = types.shape({})\on_repair (msg, err, val) ->
        assert.same msg, "table_invalid"
        assert.same err, "expecting table"
        {cool: "yes"}

      assert.same {
        {cool: "yes"}
        true
      }, {t\repair "hello!"}

    it "repairs shape with shape's repair function when extra fields", ->
      t = types.shape({})\on_repair (msg, key, val) ->
        assert.same "extra_field", msg
        assert.same "color", key
        assert.same "blue", val
        nil

      assert.same {
        {}
        true
      }, {
        t\repair {
          color: "blue"
        }
      }

    it "repairs a copy of table, instead of mutating", ->
      to_repair = { hello: 888, cool: "pants" }
      copy = {k,v for k,v in pairs to_repair}

      t = types.shape {
        hello: types.string\on_repair => "butt"
        cool: types.string
      }

      out, changed = t\repair to_repair
      assert.same { cool: "pants", hello: "butt" }, out
      assert.same true, changed

      assert.false to_repair == out

      to_repair = {hello: "zone", cool: "zone"}
      out, changed = t\repair to_repair
      assert.false changed
      assert.same { cool: "zone", hello: "zone" }, out
      assert.true out == to_repair

    describe "shape repair", ->
      local t

      before_each ->
        number = types.number\on_repair (v) ->
          tonumber(v) or 0

        color = types.shape {
          r: number
          g: number
          b: number
        }

        t = types.shape {
          name: types.string\on_repair -> "unknown"
          id: types.number\is_optional!\on_repair -> nil
          color: color
          color2: color\is_optional!
        }

      test_examples (-> t), {
        -- fixes color, provies name
        {
          input: {
            color: {
              r: "cool"
              g: "123"
              b: 99
            }
          }

          expected: {
            name: "unknown"
            color: {
              r: 0
              g: 123
              b: 99
            }
          }
        }

        -- keeps okay id
        {
          input: {
            id: 234
            color: {}
          }

          expected: {
            id: 234
            name: "unknown"
            color: {r:0, g: 0, b: 0}
          }
        }

        -- strips bad id
        {
          input: {
            name: "bum zone"
            id: "freak"
            color: {}
          }

          expected: {
            name: "bum zone"
            color: {r:0, g: 0, b: 0}
          }
        }


        -- fixed bad color2
        {
          input: {
            name: "leaf"
            color: {r:1, g: 2, b: 3}
            color2: {}
          }

          expected: {
            name: "leaf"
            color: {r:1, g: 2, b: 3}
            color2: {r: 0, g: 0, b: 0}
          }
        }

        -- fails to fix field that can't repair itself
        {
          input: {
            name: "leaf"
            color: {r:1, g: 2, b: 3}
            color2: "hello world"
          }
          fails: true
        }

      }

    describe "array_of repair", ->
      it "uses array_of's handler for plain types", ->
        a = types.array_of("hello")\on_repair (msg, idx, v)->
          assert.same "field_invalid", msg
          return nil if idx == 2
          "hello-#{idx}-#{v}"

        assert.same {{
          "hello-1-9"
          "hello-3-7"
        }, true}, { a\repair {9,8,7} }

      local t
      before_each ->
        url_shape = types.pattern("^https?://")\on_repair (val) ->
          return nil unless type(val) == "string"
          "http://#{val}"

        t = types.array_of url_shape

      test_examples (-> t), {
        -- empty array
        { input: { } }

        -- fixes all
        {
          input: { "one", "two" }
          expected: { "http://one", "http://two" }
        }

        -- fixes some
        {
          input: { "leafo.net", "https://streak.club" }
          expected: { "http://leafo.net", "https://streak.club" }
        }

        -- nil replacements are stripped from array
        {
          input: {false, false, "leafo.net", true, 234, "https://itch.io" }
          expected: {"http://leafo.net", "https://itch.io"}
        }

        -- empties out bad array
        -- TODO: we should keep the hash items
        {
          input: {1,2,3, hello: "zone"}
          expected: {}
        }
      }


