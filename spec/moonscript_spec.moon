
import instance_of from require "tableshape.moonscript"

describe "tableshape.moonscript", ->
  describe "instance_of", ->
    class Other
    class Hello
    class World extends Hello
    class Zone extends World

    it "describes type checker", ->
      assert.same "instance of Other", instance_of(Other)\_describe!
      assert.same "instance of World", instance_of("World")\_describe!

    it "handles invalid types", ->
      t = instance_of(Other)
      assert.same {nil, "expecting table"}, { t -> }
      assert.same {nil, "expecting table"}, { t false }
      assert.same {nil, "expecting table"}, { t 22 }
      assert.same {nil, "table does not have __class"}, { t {} }

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
