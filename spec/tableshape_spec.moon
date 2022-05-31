
{check_shape: check, :types} = require "tableshape"

describe "tableshape.is_type", ->
  it "detects type", ->
    import is_type, types from require "tableshape"
    assert.falsy is_type!
    assert.falsy is_type "hello"
    assert.falsy is_type {}
    assert.falsy is_type ->

    assert.truthy is_type types.string
    assert.truthy is_type types.shape {}
    assert.truthy is_type types.array_of { types.string }

describe "tableshape.type_switch", ->
  it "switches on type", ->
    import type_switch from require "tableshape"

    k = switch type_switch(5)
      when types.string
        "no"
      when types.number
        "yes"

    assert.same k, "yes"

describe "tableshape.types", ->
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
    it "type #{type_name}", ->
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

  describe "length", ->
    it "checks string length", ->
      s = types.string\length 5,20

      assert.same {
        nil
        "string length not in range from 5 to 20, got 4"
      }, {s "heck"}

      assert.same {
        true
      }, {s "hello!"}

      assert.same {
        nil
        "string length not in range from 5 to 20, got 120"
      }, {s "hello!"\rep 20}

    it "checks string length with base type", ->
      s = types.string\length types.literal 5

      assert.same {
        true
      }, {s "hello"}

      assert.same {
        nil
        'string length expected 5, got 6'
      }, {s "hello!"}

  describe "one_of", ->
    it "check value", ->
      ab = types.one_of {"a", "b"}

      assert.same nil, (ab "c")
      assert.same true, (ab "a")
      assert.same true, (ab "b")
      assert.same nil, (ab nil)

      more = types.one_of {true, 123}
      assert.same nil, (more "c")
      assert.same nil, (more false)
      assert.same nil, (more 124)
      assert.same true, (more 123)
      assert.same true, (more true)

      ab = types.one_of {
        types.literal("a")
        types.literal("b")
      }

      assert.same nil, (ab "c")
      assert.same true, (ab "a")
      assert.same true, (ab "b")
      assert.same nil, (ab nil)

      more = types.one_of {true, 123}
      assert.same nil, (more "c")
      assert.same nil, (more false)
      assert.same nil, (more 124)
      assert.same true, (more 123)
      assert.same true, (more true)

    it "check value optional", ->
      ab = types.one_of {"a", "b"}
      ab_opt = ab\is_optional!

      assert.same nil, (ab_opt "c")
      assert.same true, (ab_opt "a")
      assert.same true, (ab_opt "b")
      assert.same true, (ab_opt nil)

    it "check value with sub types", ->
      -- with sub type checkers
      misc = types.one_of { "g", types.number, types.function }

      assert.same nil, (misc "c")
      assert.same true, (misc 2354)
      assert.same true, (misc ->)
      assert.same true, (misc "g")
      assert.same nil, (misc nil)

    it "renders error message", ->
      t = types.one_of {
        "a", "b"
        types.literal "MY THING", describe: => "(my thing)"
      }

      assert.same {
        nil
        'expected "a", "b", or (my thing)'
      }, {t "wow"}

    it "shape errors", ->
      s = types.one_of {
        types.shape {
          type: "car"
          wheels: types.number
        }
        types.shape {
          type: "house"
          windows: types.number
        }
      }

      assert.true (s {
        type: "car"
        wheels: 10
      })

      -- for undefined has ordering
      errors = setmetatable {
        ['expected { "type" = "car", "wheels" = type "number" }, or { "type" = "house", "windows" = type "number" }']: true
        ['expected { "wheels" = type "number", "type" = "car" }, or { "windows" = type "number", "type" = "house" }']: true
      }, __index: (v) =>
        error "expected one of \n#{table.concat [k for k in pairs @], "\n"}\n got #{v}"

      assert.true errors[select 2, s {
        type: "car"
        wheels: "blue"
      }]

    it "creates an optimized type checker", ->
      t = types.one_of {
        "hello", "world", 5
      }

      assert.same {
        [5]: true
        "hello": true
        "world": true
      }, t.options_hash


  describe "all_of", ->
    it "checks value", ->
      t = types.all_of {
       types.string
       types.custom (k) -> k == "hello", "#{k} is not hello"
      }

      assert.same {nil, "zone is not hello"}, {t "zone"}
      assert.same {nil, 'expected type "string", got "number"'}, {t 5}

  describe "partial", ->
    it "tests partial shape", ->
      check = types.partial { color: "red" }

      -- extra data
      assert.same {true}, {
        check {
          color: "red"
          weight: 9
          age: 3
        }
      }

      assert.same {true}, {
        check {
          color: "red"
        }
      }

      -- extra data
      assert.same {nil, 'field "color": expected "red"'}, {
        check {
          color: "blue"
          weight: 9
          age: 3
        }
      }

  describe "shape", ->
    it "gets errors for multiple fields", ->
      t = types.shape {
        "blue"
        "red"
      }

      assert.same {
        nil
        'field 1: expected "blue"'
      }, {
        t {
          "orange", "blue", "purple"
        }
      }

      assert.same {
        nil
        "extra fields: 3, 4"
      }, {
        t {
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
        t {
          "orange", "blue", "purple"
        }
      }

    it "checks value", ->
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

    it "checks value with literals", ->
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

    it "checks extra fields", ->
      s = types.shape { }, {
        extra_fields: types.map_of(types.string, types.string)
      }

      assert.same {
        true
      }, {
        s {
          hello: "world"
        }
      }

      assert.same {
        nil
        'field "hello": map value expected type "string", got "number"'
      }, {
        s {
          hello: 10
        }
      }


  it "pattern", ->
    t = types.pattern "^hello"

    assert.same nil, (t 123)
    assert.same {true}, {t "hellowolr"}
    assert.same nil, (t "hell")

    t = types.pattern "^%d+$", coerce: true

    assert.same {true}, {t 123}
    assert.same {true}, {t "123"}
    assert.same nil, (t "2.5")


  it "map_of", ->
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

  describe "array_contains", ->
    it "contains number type", ->
      numbers = types.array_contains types.number
      err = 'expected array containing type "number"'

      assert.same {nil, err}, {numbers {}}
      assert.same {true}, {numbers {1}}
      assert.same {true}, {numbers {1.5}}
      assert.same {nil, err}, {numbers {"one", "two"}}
      assert.same {nil, err}, {numbers {one: 75, "ok"}}
      assert.same {true}, {numbers {"one", 73, "two"}}
      assert.same {true}, {numbers {"one", 73, 88, "two"}}

      assert.same {true}, {numbers\is_optional! nil}
      assert.same {nil, 'expected type "table", got "nil"'}, {numbers nil}

    it "contains literal number 77", ->
      has_77 = types.array_contains 77
      err = 'expected array containing 77'

      assert.same {nil, err}, {has_77 {}}
      assert.same {nil, err}, {has_77 {7}}
      assert.same {true}, {has_77 {77}}
      assert.same {true}, {has_77 {"one", 77, "two"}}
      assert.same {nil, err}, {has_77 {thing: 77}}

    it "contains shape", ->
      shapes = types.array_contains types.shape {
        color: types.one_of {"orange", "blue"}
      }
      err = 'expected array containing { "color" = "orange", or "blue" }'

      assert.same {true}, {
        shapes {
          {color: "orange"}
          {color: "blue"}
          {color: "orange"}
        }
      }

      assert.same {nil, err}, {
        shapes {
          {color: "green"}
          {color: "yellow"}
          55
        }
      }


  describe "array_of", ->
    it "of number type", ->
      numbers = types.array_of types.number

      assert.same {true}, {numbers {}}
      assert.same {true}, {numbers {1}}
      assert.same {true}, {numbers {1.5}}
      assert.same {true}, {numbers {1.5,2,3,4}}

      assert.same {true}, {numbers\is_optional! nil}
      assert.same {nil, 'expected type "table", got "nil"'}, {numbers nil}

    it "of literal string", ->
      hellos = types.array_of "hello"

      assert.same {true}, {hellos {}}
      assert.same {true}, {hellos {"hello"}}
      assert.same {true}, {hellos {"hello", "hello"}}

      assert.same {nil, 'array item 2: expected "hello"'}, {hellos {"hello", "world"}}

    it "of literal number", ->
      twothreefours = types.array_of 234

      assert.same {true}, {twothreefours {}}
      assert.same {true}, {twothreefours {234}}
      assert.same {true}, {twothreefours {234, 234}}
      assert.same {nil, 'array item 1: expected 234'}, {twothreefours {"uh"}}

    it "of shape", ->
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

      assert.same {
        nil, 'array item 3: field "color": expected "orange", or "blue"'
      }, {
        shapes {
          {color: "orange"}
          {color: "blue"}
          {color: "purple"}
        }
      }

    it "tests length", ->
      t = types.array_of types.string, length: types.range(1,3)

      assert.same {
        nil
        'array length not in range from 1 to 3, got 0'
      }, {
        t {}
      }

      assert.same {
        nil
        'expected type "table", got "string"'
      }, {
        t "hi"
      }

      assert.same {
        true
      }, {
        t {"one", "two"}
      }

      assert.same {
        nil
        'array length not in range from 1 to 3, got 4'
      }, {
        t {"one", "two", "nine", "10"}
      }

  describe "literal", ->
    it "checks value", ->
      t = types.literal "hello world"

      assert.same {true}, {t "hello world"}
      assert.same {true}, {t\check_value "hello world"}

      assert.same {
        nil, 'expected "hello world"'
      }, { t "hello zone" }

      assert.same {
        nil, 'expected "hello world"'
      }, { t\check_value "hello zone" }

      assert.same {nil, 'expected "hello world"'}, { t nil }
      assert.same {nil, 'expected "hello world"'}, { t\check_value nil }

    it "checks value when optional", ->
      t = types.literal "hello world", optional: true
      assert.same {true}, { t nil }
      assert.same {true}, { t\check_value nil}

  describe "custom", ->
    it "checks value", ->
      check = types.custom (v) ->
        if v == 1
          true
        else
          nil, "v is not 1"

      assert.same {nil, "v is not 1"}, { check 2 }
      assert.same {nil, "v is not 1"}, { check\check_value 2 }

      assert.same {nil, "v is not 1"}, { check nil }
      assert.same {nil, "v is not 1"}, { check\check_value nil }

      assert.same {true}, { check 1 }
      assert.same {true}, { check\check_value 1 }

    it "checks with default error message", ->
      t = types.custom (n) -> n % 2 == 0

      assert.same {nil, "failed custom check"}, {t 5}

    it "checks optional", ->
      check = types.custom(
        (v) ->
          if v == 1
            true
          else
            nil, "v is not 1"

        optional: true
      )

      assert.same {nil, "v is not 1"}, { check 2 }
      assert.same {nil, "v is not 1"}, { check\check_value 2 }

      assert.same {true}, { check nil }
      assert.same {true}, { check\check_value nil }

      assert.same {true}, { check 1 }
      assert.same {true}, { check\check_value 1 }

  describe "equivalent", ->
    it "chekcs nil", ->
      assert.same true, (types.equivalent(nil) nil)
      assert.same nil, (types.equivalent(nil) false)
      assert.same nil, (types.equivalent(nil) true)

    it "chekcs literal", ->
      assert.same nil, (types.equivalent("hi") nil)
      assert.same nil, (types.equivalent("hi") false)
      assert.same true, (types.equivalent("hi") "hi")

    it "checks table", ->
      assert.same true, (types.equivalent({}) {})
      assert.same true, (types.equivalent({1}) {1})
      assert.same true, (types.equivalent({hello: "world"}) {hello: "world"})
      assert.falsy (types.equivalent({hello: "world"}) {hello: "worlds"})

      assert.same nil, (types.equivalent({1}) "um")
      assert.same nil, (types.equivalent({1}) nil)


      check = types.equivalent {
        "great"
        color: {
          {}, {2}, { no: true}
        }
      }

      assert.same nil, (check\check_value "hello")
      assert.same nil, (check\check_value {})

      assert.same nil, (check\check_value {
        "great"
        color: {
          {}, {4}, { no: true}
        }
      })

      assert.same true, (check\check_value {
        "great"
        color: {
          {}, {2}, { no: true}
        }
      })

  describe "range", ->
    it "handles numeric range", ->
      r = types.range 5, 10

      assert.same {
        nil
        'range expected type "number", got "nil"'
      }, { r nil }

      assert.same { true }, { r 10 }
      assert.same { true }, { r 5 }
      assert.same { true }, { r 8 }

      assert.same {
        nil
        'not in range from 5 to 10'
      }, { r 2 }

      assert.same {
        nil
        'not in range from 5 to 10'
      }, { r 100 }

    it "handles string range", ->
      r = types.range "a", "f"

      assert.same {
        nil
        'range expected type "string", got "nil"'
      }, { r nil }

      assert.same { true }, { r "a" }
      assert.same { true }, { r "f" }
      assert.same { true }, { r "c" }

      assert.same {
        nil
        'not in range from a to f'
      }, { r "A" }

      assert.same {
        nil
        'not in range from a to f'
      }, { r "g" }

describe "tableshape.operators", ->
  it "sequence", ->
    t = types.pattern("^hello") * types.pattern("world$")
    assert.same {nil, 'doesn\'t match pattern "^hello"'}, {t("good work")}
    assert.same {nil, 'doesn\'t match pattern "world$"'}, {t("hello zone")}
    assert.same {true}, {t("hello world")}

  it "first of", ->
    t = types.pattern("^hello") + types.pattern("world$")
    assert.same {nil, 'expected pattern "^hello", or pattern "world$"'}, {t("good work")}
    assert.same {true}, {t("hello zone")}
    assert.same {true}, {t("zone world")}
    assert.same {true}, {t("hello world")}

  it "transform", ->
    -- is a noop when there is no transform
    t = types.string / "hello"
    assert.same {true}, {t("hello")}
    assert.same {nil, 'expected type "string", got "boolean"'}, {t(false)}


describe "tableshape.repair", ->
  local t
  before_each ->
    t = types.array_of(
      types.literal("nullify") / nil + types.string\on_repair (v) -> "swap"
    )\on_repair (v) ->
      if v == false
        nil
      else
        {"FAIL"}

  it "repairs array_of", ->
    assert.same {
      { "swap", "you"}
    }, {
      t\repair {22, "you"}
    }

    assert.same {
      {"FAIL"}
    }, {
      t\repair "friends"
    }

    assert.same {
      nil
      'expected array of "nullify", or type "string"'
    }, {
      t\repair false
    }

    assert.same {
      { "one", "swap", "swap", "last" }
    }, {
      t\repair {"one", 2, "nullify", true, "last"}
    }

describe "tableshape.describe", ->
  it "describes a compound type with function", ->
    s = types.nil + types.literal("hello world")
    s = s\describe -> "str('hello world')"

    assert.same { true }, {s nil}
    assert.same { true }, {s "hello world"}
    assert.same { nil, "expected str('hello world')" }, {s "cool"}

    s = types.nil / false + types.literal("hello world") / "cool"
    s = s\describe -> "str('hello world')"

    assert.same { false }, {s\transform nil}
    assert.same { "cool" }, {s\transform "hello world"}
    assert.same { nil, "expected str('hello world')" }, {s\transform "cool"}

  it "describes some common types", ->
    assert.same [[array of type "string", or type "nil"]], types.array_of(types.string + types.nil)\_describe!
    assert.same [[map of type "string" -> type "number"]], types.map_of(types.string, types.number)\_describe!
    assert.same [[type "string"]], types.proxy(-> types.string)\_describe!

    assert.same [[{ "hello" = "world" }]], types.shape({ hello: "world" })\_describe!
    assert.same [[{ "hello" = type "function" }]], types.shape({ hello: types.function })\_describe!

    assert.same [[{ "hello" = "world" }]], types.partial({ hello: "world" })\_describe!
    assert.same [[{ "hello" = type "function" }]], types.partial({ hello: types.function })\_describe!

    assert.same [[custom checker function: 0xFF]], types.custom(-> false)\_describe!\gsub "0x.+$", "0xFF"

    assert.same [[equivalent to "hi"]], types.equivalent("hi")\_describe!

    assert.same [[type "string" tagged "hi"]], types.scope(types.string, tag: "hi")\_describe!



  it "describes a compound type with string literal", ->
    s = (types.nil + types.literal("hello world"))\describe "thing"

    assert.same { true }, {s nil}
    assert.same { true }, {s "hello world"}
    assert.same { nil, "expected thing" }, {s "cool"}

    s = (types.nil / false + types.literal("hello world") / "cool")\describe "thing"

    assert.same { false }, {s\transform nil}
    assert.same { "cool" }, {s\transform "hello world"}
    assert.same { nil, "expected thing" }, {s\transform "cool"}

  it "changes error message to string", ->
    t = (types.nil + types.string)\describe {
      error: "you messed up"
      type: "nil + string"
    }

    assert.same "nil + string", t\_describe!
    assert.same {nil, "you messed up"}, { t 5 }

  it "changes error message to function", ->
    called = false
    t = (types.nil + types.string)\describe {
      error: (val, err) ->
        assert.same 'expected type "nil", or type "string"', err
        called = true
        "okay"

      type: -> "ns"
    }

    assert.same "ns", t\_describe!
    assert.same {nil, "okay"}, { t 5 }
    assert.true called


  describe "assert type", ->
    it "tests for asserted type", ->
      s = types.assert(types.number)
      assert s 10
      assert.has_error(
        -> s "hello"
        [[expected type "number", got "string"]]
      )

      ss = s * types.one_of { 5, 7 }

      assert.same {
        nil
        'expected 5, or 7'
      },  { ss 10 }

      assert.true (ss 7)

      assert.has_error(
        -> ss "hello"
        [[expected type "number", got "string"]]
      )

    it "transforms asserted type", ->
      s = types.assert(types.number)
      ss = s * types.one_of({ 5, 7 }) / (n) -> -n
      assert.same -5, (ss\transform 5)

      assert.has_error(
        -> ss ->
        [[expected type "number", got "function"]]
      )

    it "describes asserted type", ->
      s = types.assert(types.number)
      ss = s * types.one_of { 5, 7 }
      assert.same 'assert type "number"', s\_describe!
      assert.same 'assert type "number" then 5, or 7', ss\_describe!

  describe "not", ->
    it "inverts type checker", ->
      not_a_string = -types.string
      assert.true not_a_string 10
      assert.nil (not_a_string "hello")

    it "inverted type checker ignores transform", ->
      wrapped = types.string / (str) -> "wow#{str}wow"
      not_wrapped = -wrapped

      assert.same {
        nil
        'expected not type "string"'
      }, {not_wrapped\transform "hello"}

      assert.same {
        200
      }, {not_wrapped\transform 200}

    it "describes inverted type checker", ->
      not_a_string = -types.string
      assert.same 'not type "string"', not_a_string\_describe!



