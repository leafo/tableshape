
import types from require "tableshape"

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

describe "tableshape.repair", ->
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


  describe "array_of", ->
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

  describe "shape", ->
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

  describe "one_of", ->
    it "repairs with individual repair function", ->
      t = types.one_of {
        "okay"
        types.number\on_repair (val) -> tonumber val
      }

      assert.same {
        55, true
      }, {
        t\repair "55"
      }

      assert.same {
        "okay", false
      }, {
        t\repair "okay"
      }

    it "repairs with global repair function", ->
      t = types.one_of {
        "okay"
        types.number
      }, repair: (val) -> "nope"

      assert.same {
        "nope", true
      }, {
        t\repair "55"
      }

    it "repairs in order until success", ->
      k = ->

      t = types.one_of {
        types.number\on_repair (v) -> if v == "oops" then 5
        types.function\on_repair (v) -> k
      }

      assert.same {
        5, true
      }, {
        t\repair "oops"
      }

      assert.same {
        k, true
      }, {
        t\repair "well"
      }


  describe "all_of", ->
    it "repairs using global repair checker", ->
      t = types.all_of {
        types.string
      }, repair: (val) -> "okay"

      assert.same {"okay", true}, { t\repair 5 }
      assert.same {"sure", false}, { t\repair "sure" }

    it "user repair function of checker that fails", ->
      t = types.all_of {
        types.string
        types.custom(-> false)\on_repair (val) -> "fixed"
      }

      assert.same {"fixed", true}, { t\repair "wow" }

    it "fails to repair with no repair function", ->
      t = types.all_of {
        types.string
      }

      assert.has_error ->
        t\repair 5

    it "repairs with every function", ->
      t = types.all_of {
        types.table\on_repair (v) -> { v }
        types.shape {
          hello: "world"
        }, open: true, repair: (msg, field, value) -> "world"
      }

      assert.same {
        {
          "calzone"
          hello: "world"
        }
        true
      }, { t\repair "calzone" }

    it "repair short circuit", ->
      t = types.all_of {
        types.number\on_repair (v) -> tonumber v
        types.custom ((k) -> k >= 500), {
          repair: (v) -> math.max 500, v
        }
      }

      -- goes through
      assert.same {500, true}, { t\repair "5" }

      -- short circuits
      assert.same {nil, true}, { t\repair "five" }

  describe "literal", ->
    it "repairs", ->
      t = types.literal "hello world", repair: (...) ->
        assert.same (...), "zone drone"
        "FIXED"

      assert.same {
        "FIXED"
        true
      }, {
        t\repair "zone drone"
      }

  describe "custom", ->
    it "repairs", ->
      check = types.custom(
        (v) ->
          if v == 1
            true
          else
            nil, "v is not 1"

        repair: (...) ->
          assert.same {"cool", "v is not 1"}, {...}
          "okay"
      )

      assert.same {"okay", true}, { check\repair "cool" }
      assert.same {1, false}, { check\repair 1 }
