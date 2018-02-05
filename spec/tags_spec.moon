import types from require "tableshape"

describe "tableshape.tags", ->
  it "literal", ->
    t = types.literal("hi")\tag "what"
    assert.same {
      what: "hi"
    }, t("hi")

    assert.same nil, (t("no"))

  it "number", ->
    t = types.number\tag "val"
    assert.same {
      val: 15
    }, t 15

    assert.same nil, (t "no")

  describe "one_of", ->
    it "takes matching tag", ->
      s = types.one_of {
        types.string\tag "str"
        types.number\tag "num"
        types.function\tag "func"
      }

      assert.same {
        str: "hello"
      }, s "hello"

      assert.same {
        num: 5
      }, s 5

      fn = -> print "hi"
      assert.same {
        func: fn
      }, s fn

      assert.same nil, (s {})


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

      assert.same {
        table: {
          a: 43
          b: 2
          what: "ok"
        }
        x: 43
        y: 2
      }, s {
        a: 43
        b: 2
        what: "ok"
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

      out = t {
        { s: "hello" }
        { s: "world" }
      }

      assert.same {
        thing: "world"
      }, out

    it "matches many items from array", ->
      t = types.array_of types.shape {
        s: types.string\tag "thing[]"
      }

      out = t {
        { s: "hello" }
        { s: "world" }
      }

      assert.same {
        thing: {
          "hello"
          "world"
        }
      }, out

  describe "map_of", ->
    it "matches regular map", ->
      t = types.map_of "hello", types.string\tag "world"

      assert.same {
        world: "something"
      }, t {
        hello: "something"
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

      tags = assert s {
        1
        2
        3
        t: "board"
        color: "blue"
      }

      assert.same {
        x: 1
        y: 2
        color: "blue"
      }, tags


    it "shape doesn't return partial tags", ->
      t = types.shape {
        types.string\tag "hello"
        types.string\tag "world"
      }

      s = {}
      t { "one", "two" }, s

      assert.same {
        hello: "one"
        world: "two"
      }, s

      s = {}
      t { "one", 5 }, s
      assert.same {}, s


