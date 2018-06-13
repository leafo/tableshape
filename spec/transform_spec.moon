import types from require "tableshape"

describe "tableshape.transform", ->
  it "transform node", ->
    n = types.string / (str) -> "--#{str}--"
    assert.same {
      "--hello--"
    }, {n\transform "hello"}

    assert.same {
      nil
      'expected type "string", got "number"'
    }, {n\transform 5}

    r = types.range(1,5) / (n) -> n * 10
    assert.same { 40 }, {r\transform 4}
    assert.same { nil, 'not in range from 1 to 5' }, {r\transform 20}

  it "sequnce node", ->
    n = types.string * types.literal "hello"

    assert.same {
      "hello"
    }, { n\transform "hello" }

    assert.same {
      nil
      'expected "hello"'
    }, { n\transform "world" }

    assert.same {
      nil
      'expected type "string", got "boolean"'
    }, { n\transform true }

  it "first of node", ->
    n = types.literal(55) + types.string + types.array

    assert.same {
      nil
      'expected 55, type "string", or an array'
    }, { n\transform 65 }

    assert.same {
      "does this work?"
    }, {
      n\transform "does this work?"
    }

    assert.same {
      55
    }, {
      n\transform 55
    }

    assert.same {
      {1,2,3}
    }, {
      n\transform {1,2,3}
    }

  describe "shape", ->
    it "handles literal", ->
      n = types.shape {
        color: "blue"
      }

      assert.same {
        nil
        'field "color": expected "blue"'
      }, { n\transform { color: "red" } }

      assert.same {
        {
          color: "blue"
        }
      }, { n\transform { color: "blue" } }

    it "returns same object", ->
      n = types.shape {
        color: "red"
      }

      input = { color: "red" }

      output = assert n\transform input
      assert input == output, "expected output to be same object as input"

    it "handles dirty key in extra_fields", ->
      n = types.shape {
        height: types.number
      }, extra_fields: types.map_of((types.literal("hello") / "world") + types.string, types.string)

      input = { height: 55 }
      output = assert n\transform input
      assert input == output, "expected output to be same object as input"

      input = { height: 55, one: "two" }
      output = assert n\transform input
      assert input == output, "expected output to be same object as input"

      input = { height: 55, one: "two", hello: "thing" }
      output = assert n\transform input
      assert input != output, "expected output different object"
      assert.same {
        world: "thing"
        one: "two"
        height: 55
      }, output

    it "handles dirty value in extra_fields", ->
      n = types.shape {
        height: types.number
      }, extra_fields: types.map_of(types.string, (types.literal("n") / "b") + types.string)

      input = { height: 55 }
      output = assert n\transform input
      assert input == output, "expected output to be same object as input"

      input = { height: 55, hi: "hi" }
      output = assert n\transform input
      assert input == output, "expected output to be same object as input"

      input = { height: 55, hi: "n" }
      output = assert n\transform input
      assert input != output, "expected output to be different object from input"
      assert.same {
        height: 55
        hi: "b"
      }, output

    it "handles dirty value when removing field from extra_fields", ->
      n = types.shape {
        one: types.string
      }, extra_fields: types.map_of(types.number, types.any) + types.any / nil

      input = { one: "two" }
      output = assert n\transform input
      assert input == output, "expected output to be same object as input"

      input = { one: "two", "yes" }
      output = assert n\transform input
      assert input == output, "expected output to be same object as input"

      input = { one: "two", some: "thing" }
      output = assert n\transform input
      assert input != output, "expected output to be different object as input"
      assert.same {
        one: "two"
      }, output

    it "handles non table", ->
      n = types.shape {
        color: types.literal "red"
      }

      assert.same {
        nil
        'expected type "table", got "boolean"'
      }, {
        n\transform true
      }

    it "single field", ->
      n = types.shape {
        color: types.one_of { "blue", "green", "red"}
      }

      assert.same {
        nil
        'field "color": expected "blue", "green", or "red"'
      },{
        n\transform { color: "purple" }
      }

      assert.same {
        { color: "green" }
      },{
        n\transform { color: "green" }
      }

      assert.same {
        nil
        'extra fields: "height"'
      },{
        n\transform { color: "green", height: "10" }
      }

      assert.same {
        nil
        'extra fields: 1, 2, "cool"'
      },{
        n\transform { color: "green", cool: "10", "a", "b" }
      }

    it "single field nil", ->
      n = types.shape {
        friend: types.nil
      }

      assert.same {
        {}
      },{
        n\transform {}
      }

      assert.same {
        nil
        'field "friend": expected type "nil", got "string"'
      },{
        n\transform { friend: "what up" }
      }

    it "single field with transform", ->
      n = types.shape {
        value: types.one_of({ "blue", "green", "red"}) + types.string / "unknown" + types.number / (n) -> n + 5
      }

      assert.same {
        nil
        'field "value": expected "blue", "green", or "red", type "string", or type "number"'
      }, {
        n\transform { }
      }


      assert.same {
        { value: "red" }
      }, {
        n\transform {
          value: "red"
        }
      }

      assert.same {
        { value: "unknown" }
      }, {
        n\transform {
          value: "purple"
        }
      }

      assert.same {
        { value: 15 }
      }, {
        n\transform {
          value: 10
        }
      }

    it "single field open table", ->
      n = types.shape {
        age: (types.table + types.number / (v) -> {seconds: v}) * types.shape {
          seconds: types.number
        }
      }, open: true

      assert.same {
        {
          age: {
            seconds: 10
          }
        }
      }, {
        n\transform {
          age: 10
        }
      }

      assert.same {
        {
          age: {
            seconds: 12
          }
        }
      }, {
        n\transform {
          age: 12
        }
      }

      assert.same {
        nil
        'field "age": expected type "table", or type "number"'
      }, {
        n\transform {
          age: "hello"
        }
      }

      assert.same {
        nil
        'field "age": expected type "table", or type "number"'
      }, {
        n\transform {
          age: "hello"
          another: "one"
        }
      }

      assert.same {
        {
          age: {
            seconds: 10
          }
          one: "two"
        }
      }, {
        n\transform {
          age: 10
          one: "two"
        }
      }

      assert.same {
        {
          color: "red"
          age: { seconds: 12 }
          another: {
            1,2,4
          }
        }
      }, {
        n\transform {
          color: "red"
          age: 12
          another: {1,2,4}
        }
      }

    it "multiple failures & check_all", ->
      t = types.shape {
        "blue"
        "red"
      }

      assert.same {
        nil
        'field 1: expected "blue"'
      }, {
        t\transform {
          "orange", "blue", "purple"
        }
      }

      assert.same {
        nil
        "extra fields: 3, 4"
      }, {
        t\transform {
          "blue", "red", "purple", "yello"
        }
      }

      t = types.shape {
        "blue"
        "red"
      }, check_all: true

      assert.same {
        nil
        'field 1: expected "blue"; field 2: expected "red"; extra fields: 3'
      }, {
        t\transform {
          "orange", "blue", "purple"
        }
      }

    it "extra field", ->
      s = types.shape { }, {
        extra_fields: types.map_of(types.string, types.string)
      }

      assert.same {
        { hello: "world" }
      }, {
        s\transform {
          hello: "world"
        }
      }

      assert.same {
        nil
        -- TODO: this error message not good
        'field "hello": map value expected type "string", got "number"'
      }, {
        s\transform {
          hello: 10
        }
      }

      s = types.shape { }, {
        extra_fields: types.map_of(types.string, types.string / tonumber)
      }

      assert.same {
        { }
      }, {
        s\transform { hello: "world" }
      }

      assert.same {
        { hello: 15 }
      }, {
        s\transform { hello: "15" }
      }

      s = types.shape { }, {
        extra_fields: types.map_of(
          (types.string / (s) -> "junk_#{s}") + types.any / nil
          types.any
        )
      }


      assert.same {
        { junk_hello: true }
      }, {
        s\transform { hello: true, 1,2,3, [false]: "yes" }
      }

      s = types.shape {
        color: types.string
      }, extra_fields: types.any / nil

      assert.same {
        {color: "red"}
      }, {
        s\transform {
          color: "red"
          1,2,3
          another: "world"
        }
      }


  describe "array_of", ->
    it "handles non table", ->
      n = types.array_of types.literal "world"

      assert.same {
        nil
        'expected type "table", got "boolean"'
      }, {
        n\transform true
      }

    it "returns same object if no transforms happen", ->
      n = types.array_of types.number + types.string / "YA"
      arr = {5, 2, 1.7, 2}
      res = n\transform arr
      assert.true arr == res
      assert.same {
        5, 2, 1.7, 2
      }, res

    it "returns new object if when transforming", ->
      n = types.array_of types.number + types.string / "YA"

      arr = {5,"hello",7,8}
      res = n\transform arr

      assert.false arr == res
      assert.same { 5,"hello",7,8 }, arr
      assert.same { 5, "YA", 7, 8}, res

      arr = {"hello",7,"world"}
      res = n\transform arr

      assert.false arr == res
      assert.same {"hello",7,"world"}, arr
      assert.same {"YA", 7, "YA"}, res

    it "returns new object when stripping nils", ->
      n = types.array_of types.number + types.string / nil

      arr = {5,"hello",7,8}
      res = n\transform arr

      assert.false arr == res
      assert.same { 5,"hello",7,8 }, arr
      assert.same { 5, 7, 8}, res

      n2 = types.array_of types.number + types.string / nil, {
        keep_nils: true
      }

      arr = {5,"hello",7,8}
      res = n2\transform arr

      assert.false arr == res
      assert.same { 5, "hello", 7, 8 }, arr
      assert.same { 5, nil, 7, 8 }, res


    it "transforms array items", ->
      n = types.array_of types.string + types.number / (n) -> "number: #{n}"

      assert.same {
        {
          "number: 1"
          "one"
          "number: 3"
        }
      }, {
        n\transform { 1,"one",3 }
      }

      assert.same {
        nil
        'array item 2: expected type "string", or type "number"'
      }, {
        n\transform {1, true}
      }

    it "transforms array with literals", ->
      n = types.array_of 5

      assert.same {
        { 5,5 }
      },{
        n\transform { 5, 5 }
      }

      assert.same {
        nil
        'array item 2: expected 5'
      },{
        n\transform { 5, 6 }
      }

    it "transforms empty array", ->
      n = types.array_of types.string
      assert.same {
        {}
      }, { n\transform {} }

    it "strips nil values", ->
      filter = types.array_of types.string + types.any / nil

      assert.same {
        { "one", "hello" }
      }, {
        filter\transform {
          "one", 5, (->), "hello", true
        }
      }

    it "keeps nil values", ->
      filter = types.array_of types.string + types.any / nil, {
        keep_nils: true
      }

      assert.same {
        { "one", nil, nil, "hello", nil }
      }, {
        filter\transform {
          "one", 5, (->), "hello", true
        }
      }

    it "tests length", ->
      f = types.array_of types.string + types.any / nil, length: types.range 2,3
      assert.same {
        {"one", "two"}
      }, {
        f\transform {"one", true, "two"}
      }

      assert.same {
        nil
        'array length not in range from 2 to 3, got 4'
      }, {
        f\transform {"one", true, "two", false}
      }

  describe "map_of", ->
    it "non table", ->
      n = types.map_of types.string, types.string

      assert.same {
        nil
        'expected type "table", got "boolean"'
      }, {
        n\transform true
      }

    it "returns same object", ->
      n = types.map_of types.string, types.string + types.number / (v) -> tostring v

      input = { one: 5 }
      output = assert n\transform input
      assert input != output, "expected output to be same object as input"
      assert.same { one: "5" }, output

      input = { one: "two" }
      output = assert n\transform input
      assert input == output, "expected output to be same object as input"

    it "empty table", ->
      n = types.map_of types.string, types.string
      input = {}
      output = assert n\transform input
      -- it returns same object
      assert.true input == output

    it "transforms keys & values", ->
      n = types.map_of(
        types.string + types.number / tostring
        types.number + types.string / tonumber
      )

      input = {
        "10"
        "20"
      }

      output = assert n\transform input

      assert.false input == output

      assert.same {
        "1": 10
        "2": 20
      }, output

      --input is unchanged
      assert.same {
        "10", "20"
      }, input

      assert.same {
        nil
        'map value expected type "number", or type "string"'
      }, {
        n\transform {
          hello: true
        }
      }

      assert.same {
        nil
        'map key expected type "string", or type "number"'
      }, {
        n\transform {
          [true]: 10
        }
      }

    it "transforms to new object with nested transform", ->
      t = types.map_of types.string, types.array_of types.number + types.string / nil

      input = {
        hello: {}
        world: {1}
        zone: {1,2}
      }

      output = assert t\transform input
      assert.true input == output

      input = {
        hello: {}
        world: {1}
        one: {"one",2}
        zone: {1,2}
      }
      output = assert t\transform input

      assert.false input == output
      assert.same {
        hello: {}
        world: {1}
        one: {2}
        zone: {1,2}
      }, output

      assert.same {
        hello: {}
        world: {1}
        one: {"one",2}
        zone: {1,2}
      }, input

      assert.true input.zone == output.zone
      assert.true input.hello == output.hello

    it "transforms key & value literals", ->
      n = types.map_of 5, "hello"

      assert.same {
        { [5]: "hello" }
      }, {
        n\transform {
          [5]: "hello"
        }
      }

      assert.same {
        nil
        'map value expected "hello"'
      }, {
        n\transform {
          [5]: "helloz"
        }
      }

      assert.same {
        nil
        "map key expected 5"
      }, {
        n\transform {
          "5": "hello"
        }
      }

    it "removies fields by transforming to nil", ->
      t = types.map_of types.string, types.number + types.any / nil

      assert.same {
        age: 10
        id: 99.9
      }, t\transform {
        color: "blue"
        age: 10
        id: 99.9
      }

      t = types.map_of types.string + types.any / nil, types.any

      assert.same {
        color: "blue"
      }, t\transform {
        color: "blue"
        [5]: 10
        [true]: "okay"
      }

  describe "tags", ->
    it "assigns tags when transforming", ->
      n = types.shape {
        (types.number / tostring + types.string)\tag "hello"
        (types.number / tostring + types.string)\tag "world"
      }

      assert.same {
        {
          "5"
          "world"
        }
        {
          hello: "5"
          world: "world"
        }
      }, {
        n\transform {
          5
          "world"
        }
      }

