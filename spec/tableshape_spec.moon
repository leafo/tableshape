
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
        "value `wow` does not match one of: `a`, `b`, (my thing)"
      }, {t "wow"}

  describe "all_of", ->
    it "checks value", ->
      t = types.all_of {
       types.string
       types.custom (k) -> k == "hello", "#{k} is not hello"
      }

      assert.same {nil, "zone is not hello"}, {t "zone"}
      assert.same {nil, "got type `number`, expected `string`"}, {t 5}

  describe "shape", ->
    it "gets field errors, short_circuit", ->
      check = types.shape { color: "red" }
      assert.same "field `color` expected `red`, got `nil`", select 2, check\check_fields {}, true
      assert.same "expecting table", select 2, check\check_fields "blue", true
      assert.same "has extra field: `height`", select 2, check\check_fields { color: "red", height: 10 }, true
      assert.same true, check\check_fields { color: "red" }, true

    it "gets field errors", ->
      check = types.shape { color: "red" }

      assert.same {
        "field `color` expected `red`, got `nil`"
        color: "expected `red`, got `nil`"
      }, select 2, check\check_fields {}, false

      assert.same {"expecting table"}, select 2, check\check_fields "blue"
      assert.same {"has extra field: `height`"}, select 2, check\check_fields { color: "red", height: 10 }
      assert.same {}, select 2, check\check_fields { color: "red" }

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

  describe "array_of", ->
    it "of number type", ->
      numbers = types.array_of types.number

      assert.same {true}, {numbers {}}
      assert.same {true}, {numbers {1}}
      assert.same {true}, {numbers {1.5}}
      assert.same {true}, {numbers {1.5,2,3,4}}

      assert.same {true}, {numbers\is_optional! nil}
      assert.same nil, (numbers nil)

    it "of literal string", ->
      hellos = types.array_of "hello"

      assert.same {true}, {hellos {}}
      assert.same {true}, {hellos {"hello"}}
      assert.same {true}, {hellos {"hello", "hello"}}

      assert.same nil, (hellos {"hello", "world"})

    it "of literal number", ->
      twothreefours = types.array_of 234

      assert.same {true}, {twothreefours {}}
      assert.same {true}, {twothreefours {234}}
      assert.same {true}, {twothreefours {234, 234}}
      assert.same nil, (twothreefours {"uh"})

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

      assert.same nil, (
        shapes {
          {color: "orange"}
          {color: "blue"}
          {color: "purple"}
        }
      )


  describe "literal", ->
    it "checks value", ->
      t = types.literal "hello world"

      assert.same {true}, {t "hello world"}
      assert.same {true}, {t\check_value "hello world"}

      assert.same {
        nil, "got `hello zone`, expected `hello world`"
      }, { t "hello zone" }

      assert.same {
        nil, "got `hello zone`, expected `hello world`"
      }, { t\check_value "hello zone" }

      assert.same {nil, "got `nil`, expected `hello world`"}, { t nil }
      assert.same {nil, "got `nil`, expected `hello world`"}, { t\check_value nil }

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

      assert.same {nil, "5 is invalid"}, {t 5}

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
    it "checks value", ->
      assert.same true, (types.equivalent({}) {})
      assert.same true, (types.equivalent({1}) {1})
      assert.same true, (types.equivalent({hello: "world"}) {hello: "world"})
      assert.falsy (types.equivalent({hello: "world"}) {hello: "worlds"})

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
        "range got type `nil`, expected `number`"
      }, { r nil }

      assert.same { true }, { r 10 }
      assert.same { true }, { r 5 }
      assert.same { true }, { r 8 }

      assert.same {
        nil
        "`2` is not between [5, 10]"
      }, { r 2 }

      assert.same {
        nil
        "`100` is not between [5, 10]"
      }, { r 100 }

    it "handles string range", ->
      r = types.range "a", "f"

      assert.same {
        nil
        "range got type `nil`, expected `string`"
      }, { r nil }

      assert.same { true }, { r "a" }
      assert.same { true }, { r "f" }
      assert.same { true }, { r "c" }

      assert.same {
        nil
        "`A` is not between [a, f]"
      }, { r "A" }

      assert.same {
        nil
        "`g` is not between [a, f]"
      }, { r "g" }

describe "tableshape.operators", ->
  it "sequence", ->
    t = types.pattern("^hello") * types.pattern("world$")
    assert.same {nil, "doesn't match pattern `^hello`"}, {t("good work")}
    assert.same {nil, "doesn't match pattern `world$`"}, {t("hello zone")}
    assert.same {true}, {t("hello world")}

  it "first of", ->
    t = types.pattern("^hello") + types.pattern("world$")
    assert.same {nil, "no matching option (doesn't match pattern `^hello`; doesn't match pattern `world$`)" }, {t("good work")}
    assert.same {true}, {t("hello zone")}
    assert.same {true}, {t("zone world")}
    assert.same {true}, {t("hello world")}

  it "transform", ->
    -- is a noop when there is no transform
    t = types.string / "hello"
    assert.same {true}, {t("hello")}
    assert.same {nil, "got type `boolean`, expected `string`"}, {t(false)}


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
      "no matching option (got type `boolean`, expected `table`; got type `nil`, expected `table`)"
    }, {
      t\repair false
    }

    assert.same {
      { "one", "swap", "swap", "last" }
    }, {
      t\repair {"one", 2, "nullify", true, "last"}
    }
