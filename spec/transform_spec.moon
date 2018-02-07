import types from require "tableshape"

describe "tableshape.transform", ->
  it "transform node", ->
    n = types.string / (str) -> "--#{str}--"
    assert.same {
      "--hello--"
    }, {n\transform "hello"}

    assert.same {
      nil
      "got type `number`, expected `string`"
    }, {n\transform 5}

    r = types.range(1,5) / (n) -> n * 10
    assert.same { 40 }, {r\transform 4}
    assert.same { nil, "`20` is not in range [1, 5]" }, {r\transform 20}

  it "sequnce node", ->
    n = types.string * types.literal "hello"

    assert.same {
      "hello"
    }, { n\transform "hello" }

    assert.same {
      nil
      "got `world`, expected `hello`"
    }, { n\transform "world" }

    assert.same {
      nil
      "got type `boolean`, expected `string`"
    }, { n\transform true }

  it "first of node", ->
    n = types.literal(55) + types.string + types.array

    assert.same {
      nil
      "no matching option (got `65`, expected `55`; got type `number`, expected `string`; expecting table)"
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
    it "handles non table", ->
      n = types.shape {
        color: types.literal "red"
      }

      assert.same {
        nil
        "got type `boolean`, expected `table`"
      }, {
        n\transform true
      }

    it "single field", ->
      n = types.shape {
        color: types.one_of { "blue", "green", "red"}
      }

      assert.same {
        nil
        "field `color`: value `purple` does not match one of: `blue`, `green`, `red`"
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
        "extra fields: `height`"
      },{
        n\transform { color: "green", height: "10" }
      }

      assert.same {
        nil
        "extra fields: `1`, `2`, `cool`"
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
        "field `friend`: got type `string`, expected `nil`"
      },{
        n\transform { friend: "what up" }
      }

    it "single field with transform", ->
      n = types.shape {
        value: types.one_of({ "blue", "green", "red"}) + types.string / "unknown" + types.number / (n) -> n + 5
      }

      assert.same {
        nil
        "field `value`: no matching option (value `nil` does not match one of: `blue`, `green`, `red`; got type `nil`, expected `string`; got type `nil`, expected `number`)"
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
        "field `age`: no matching option (got type `string`, expected `table`; got type `string`, expected `number`)"
      }, {
        n\transform {
          age: "hello"
        }
      }

      assert.same {
        nil
        "field `age`: no matching option (got type `string`, expected `table`; got type `string`, expected `number`)"
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
        "field `hello`: map value got type `number`, expected `string`"
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
        "got type `boolean`, expected `table`"
      }, {
        n\transform true
      }

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
        "array item 2: no matching option (got type `boolean`, expected `string`; got type `boolean`, expected `number`)"
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
        "array item 2: got `6`, expected `5`"
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
        "array length `4` is not in range [2, 3]"
      }, {
        f\transform {"one", true, "two", false}
      }

  describe "map_of", ->
    it "non table", ->
      n = types.map_of types.string, types.string

      assert.same {
        nil
        "got type `boolean`, expected `table`"
      }, {
        n\transform true
      }


    it "empty table", ->
      n = types.map_of types.string, types.string
      assert.same {
        {}
      }, {
        n\transform {}
      }

    it "transforms keys & values", ->
      n = types.map_of(
        types.string + types.number / tostring
        types.number + types.string / tonumber
      )

      assert.same {
        {
          "1": 10
          "2": 20
        }
      }, {
        n\transform {
          "10"
          "20"
        }
      }

      assert.same {
        nil
        "map value no matching option (got type `boolean`, expected `number`; got type `boolean`, expected `string`)"
      }, {
        n\transform {
          hello: true
        }
      }

      assert.same {
        nil
        "map key no matching option (got type `boolean`, expected `string`; got type `boolean`, expected `number`)"
      }, {
        n\transform {
          [true]: 10
        }
      }

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
        "map value got `helloz`, expected `hello`"
      }, {
        n\transform {
          [5]: "helloz"
        }
      }

      assert.same {
        nil
        "map key got `5`, expected `5`"
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

