
import instance_of, class_type, instance_type from require "tableshape.moonscript"

describe "tableshape.moonscript", ->
  class Other
  class Hello
  class World extends Hello
  class Zone extends World

  describe "instance_type", ->
    it "describes", ->
      assert.same "class", tostring class_type

    it "tests values", ->
      assert instance_type Other!
      assert instance_type Zone!

      assert.same {
        nil
        "expecting table"
      }, { instance_type true }

      assert.same {
        nil
        "expecting table"
      }, { instance_type -> }

      assert.same {
        nil
        "expecting table"
      }, { instance_type nil }

      -- random table
      assert.same {
        nil
        "table is not instance (missing metatable)"
      }, { instance_type {} }

      -- a class object (is not an instance)
      assert.same {
        nil
        "table is not instance (metatable does not have __class)"
      }, { instance_type World }

  describe "class_type", ->
    it "describes type checker", ->
      assert.same "class", tostring class_type

    it "tests values", ->
      assert.same {
        nil
        "table is not class (missing __base)"
      }, { class_type Hello! }

      assert.true, class_type Hello

      assert.same {
        nil
        "expecting table"
      }, { class_type false }

      assert.same {
        nil
        "table is not class (missing __base)"
      }, { class_type {} }

      assert.same {
        nil
        "table is not class (__base not table)"
      }, { class_type { __base: "world" } }

      assert.same {
        nil
        "table is not class (missing metatable)"
      }, { class_type { __base: {}} }

      assert.same {
        nil
        "table is not class (no constructor)"
      }, { class_type setmetatable { __base: {}}, {} }

  describe "instance_of", ->
    it "describes type checker", ->
      assert.same "instance of Other", tostring instance_of Other
      assert.same "instance of World", tostring instance_of "World"

    it "handles invalid types", ->
      t = instance_of(Other)
      assert.same {nil, "expecting table"}, { t -> }
      assert.same {nil, "expecting table"}, { t false }
      assert.same {nil, "expecting table"}, { t 22 }
      assert.same {nil, "table is not instance (missing metatable)"}, { t {} }
      assert.same {nil, "table is not instance (metatable does not have __class)"}, { t setmetatable  {}, {} }

    it "checks instance of class by name", ->
      -- by zone
      assert.true instance_of("Zone") Zone!

      assert.same {
        nil, "table is not instance of Zone"
      }, { instance_of("Zone") World! }

      assert.same {
        nil, "table is not instance of Zone"
      }, { instance_of("Zone") Hello! }

      assert.same {
        nil, "table is not instance of Zone"
      }, { instance_of("Zone") Other! }

      -- by world
      assert.true instance_of("World") Zone!
      assert.true instance_of("World") World!

      assert.same {
        nil, "table is not instance of World"
      }, { instance_of("World") Hello! }

      assert.same {
        nil, "table is not instance of World"
      }, { instance_of("World") Other! }

      -- by hello
      assert.true instance_of("Hello") Zone!
      assert.true instance_of("Hello") World!
      assert.true instance_of("Hello") Hello!

      assert.same {
        nil, "table is not instance of Hello"
      }, { instance_of("Hello") Other! }

      -- by other
      assert.same {
        nil, "table is not instance of Other"
      }, { instance_of("Other") World! }

      assert.same {
        nil, "table is not instance of Other"
      }, { instance_of("Other") World! }

      assert.same {
        nil, "table is not instance of Other"
      }, { instance_of("Other") Hello! }

      assert.true instance_of("Other") Other!


    it "checks instance of class by object", ->
      -- by zone
      assert.true instance_of(Zone) Zone!

      -- it should not think a class object is an instance
      assert.same {
        nil, "table is not instance (metatable does not have __class)"
      }, { instance_of(Zone) Zone }

      assert.same {
        nil, "table is not instance of Zone"
      }, { instance_of(Zone) World! }

      assert.same {
        nil, "table is not instance of Zone"
      }, { instance_of(Zone) Hello! }

      assert.same {
        nil, "table is not instance of Zone"
      }, { instance_of(Zone) Other! }

      -- by world
      assert.true instance_of(World) Zone!
      assert.true instance_of(World) World!

      assert.same {
        nil, "table is not instance of World"
      }, { instance_of(World) Hello! }

      assert.same {
        nil, "table is not instance of World"
      }, { instance_of(World) Other! }

      -- by hello
      assert.true instance_of(Hello) Zone!
      assert.true instance_of(Hello) World!
      assert.true instance_of(Hello) Hello!

      assert.same {
        nil, "table is not instance of Hello"
      }, { instance_of(Hello) Other! }

      -- by other
      assert.same {
        nil, "table is not instance of Other"
      }, { instance_of(Other) World! }

      assert.same {
        nil, "table is not instance of Other"
      }, { instance_of(Other) World! }

      assert.same {
        nil, "table is not instance of Other"
      }, { instance_of(Other) Hello! }

      assert.true instance_of(Other) Other!
