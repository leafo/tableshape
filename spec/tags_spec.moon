import types from require "tableshape"

-- test tags output from both check_value and transform
assert_tags = (t, arg, expected)->
  assert.same expected, (t(arg))
  out, tags = t\transform arg
  assert.same expected, out and tags or nil

describe "tableshape.tags", ->
  it "literal", ->
    t = types.literal("hi")\tag "what"
    assert_tags t, "hi", {
      what: "hi"
    }

    assert_tags t, "no", nil

  it "number", ->
    t = types.number\tag "val"
    assert_tags t, 15, {
      val: 15
    }

    assert_tags t, "no", nil

  it "string", ->
    t = types.string\length(types.range(1,2)\tag "len")\tag "val"
    assert_tags t, "hi", {
      val: "hi"
      len: 2
    }

  describe "function tag", ->
    it "tags basic object", ->
      t = types.array_of types.literal("hi")\tag (state, val) ->
        assert.same "hi", val

        if state.count
          state.count += 1
        else
          state.count = 1

      assert_tags t, {"hi"}, {
        count: 1
      }

      assert_tags t, {"hi", "hi", "hi"}, {
        count: 3
      }

  describe "scope", ->
    it "stores scoped tags into array", ->
      obj = types.shape {
        name: types.string\tag "name"
      }, open: true

      larp = types.literal "larp"
      bart = types.literal("bart")\tag "other"

      s = types.shape {
        things: types.array_of types.scope(obj + larp + bart, tag: "names[]")
        color: types.string\tag "color"
      }

      assert_tags s, {
        color: "blue"
        things: {
          { name: "bart", height: 10 }
          "larp"
          { name: "narf", color: "blue" }
          "larp"
          "bart"
          { name: "woopsie"}
          "larp"
        }
      }, {
        color: "blue"
        names: {
          { name: "bart" }
          { name: "narf" }
          { other: "bart" }
          { name: "woopsie" }
        }
      }

    it "drops scope with no name", ->
      scoped = types.scope types.shape({
        hello: types.string\tag "thing"
      }) % (value, state) ->
        "value: #{state.thing}"

      t = types.shape {
        name: types.string\tag "the_name"
        items: types.array_of scoped
      }

      obj, state = assert t\transform {
        name: "dodo"
        items: {
          { hello: "world" }
          { hello: "zone" }
        }
      }

      assert.same {
        name: "dodo"
        items: {
          "value: world"
          "value: zone"
        }
      }, obj

      assert.same {
        the_name: "dodo"
      }, state


    it "scope and function tag", ->
      o = types.shape {
        [1]: types.number\tag "id"
        name: types.string\tag "name"
      }

      called = 0

      s = types.shape {
        types.string\tag "color"
        types.scope o, tag: (state, val, val_state) ->
          called += 1

          -- the state of the current scope
          assert.same { color: "red" }, state

          -- the value being checked
          assert.same {
            1234
            name: "hello"
          }, val

          -- the state captured from the value
          assert.same { name: "hello", id: 1234 }, val_state

          state.the_name = val_state.name
      }

      assert_tags s, {
        "red"
        {
          1234
          name: "hello"
        }
      }, {
        color: "red"
        the_name: "hello"
      }

      assert.same 2, called

  describe "one_of", ->
    it "takes matching tag", ->
      s = types.one_of {
        types.string\tag "str"
        types.number\tag "num"
        types.function\tag "func"
      }

      assert_tags s, "hello", {
        str: "hello"
      }

      assert_tags s, 5, {
        num: 5
      }

      fn = -> print "hi"
      assert_tags s, fn, {
        func: fn
      }

      assert_tags s, {}, nil

  describe "all_of", ->
    it "matches multi", ->
      s = types.all_of {
        types.table\tag "table"
        types.shape {
          a: types.number\tag "x"
        }, open: true
        types.shape {
          b: types.number\tag "y"
        }, open: true
      }

      assert_tags s, {
        a: 43
        b: 2
        what: "ok"
      }, {
        table: {
          a: 43
          b: 2
          what: "ok"
        }
        x: 43
        y: 2
      }

      tags = {}
      assert.nil (s {}, tags)
      assert.same {}, tags

      tags = {}
      assert.nil (s { a: 443}, tags)
      assert.same {}, tags

      tags = {}
      assert.nil (s { a: 443, b: "no"}, tags)
      assert.same {}, tags

  describe "array_of", ->
    it "matches array", ->
      t = types.array_of types.shape {
        s: types.string\tag "thing"
      }

      assert_tags t, {
        { s: "hello" }
        { s: "world" }
      }, {
        thing: "world"
      }

    it "matches array length", ->
      t = types.array_of types.string, length: types.range(1,2)\tag "len"

      assert_tags t, {
        "one"
        "two"
      }, {
        len: 2
      }

      assert_tags t, {
        "one"
      }, {
        len: 1
      }

      assert_tags t, {
        "one"
        "one1"
        "one2"
      }, nil

    it "matches many items from array", ->
      t1 = types.array_of types.number\tag "hi[]"

      assert_tags t1, { 1,2,3,4 }, {
        hi: {1,2,3,4}
      }


      t = types.array_of types.shape {
        s: types.string\tag "thing[]"
      }

      assert_tags t, {
        { s: "hello" }
        { s: "world" }
      }, {
        thing: {
          "hello"
          "world"
        }
      }

  describe "map_of", ->
    it "matches regular map", ->
      t = types.map_of "hello", types.string\tag "world"

      assert_tags t, {
        hello: "something"
      }, {
        world: "something"
      }


  describe "shape", ->
    it "basic shape", ->
      s = types.shape {
        types.number\tag "x"
        types.number\tag "y"
        types.number
        t: types.string
        color: types.string\tag "color"
      }

      assert_tags s, {
        1
        2
        3
        t: "board"
        color: "blue"
      }, {
        x: 1
        y: 2
        color: "blue"
      }

    it "doesn't write partial tags", ->
      t = types.shape {
        types.string\tag "hello"
        types.string\tag "world"
      }

      out = t { "one", "two" }, {}

      assert.same {
        hello: "one"
        world: "two"
      }, out

    it "doesn't mutate state object", ->
      t = types.shape {
        types.string\tag "hello"
        types.string\tag "world"
      }

      -- doesn't mutate state
      s = {}
      t { "one", 5 }, s
      assert.same {}, s

    it "throws out state from partial match", ->
      t = types.shape {
        types.string\tag "str[]"
        types.one_of {
          types.array_of(types.string\tag "str[]")
          types.array_of((types.string + types.number)\tag "str_or_number[]")
        }
      }

      out = t {
        "alpha"
        { "one", "two", 3 }
      }

      assert.same {
        str: {"alpha"}
        str_or_number: {"one", "two", 3}
      }, out

      -- sanity check, for when it matches
      out = t {
        "alpha"
        { "one", "two", "three" }
      }

      assert.same {
        str: {"alpha", "one", "two", "three"}
      }, out

    it "gets tagged extra fields", ->
      s = types.shape {
        color: types.string
      }, {
        extra_fields: types.map_of types.string\tag("extra_key[]"), types.string\tag("extra_val[]")
      }

      assert_tags s, {
        color: "blue"
        height: "10cm"
      }, {
        extra_key: {"height"}
        extra_val: {"10cm"}
      }

