import to_json_schema from require "tableshape.json_schema"
import types from require "tableshape"

describe "tableshape.json_schema", ->
  describe "basic types", ->
    it "converts string type", ->
      result = to_json_schema\transform types.string
      assert.same {type: "string"}, result

    it "converts number type", ->
      result = to_json_schema\transform types.number
      assert.same {type: "number"}, result

    it "converts boolean type", ->
      result = to_json_schema\transform types.boolean
      assert.same {type: "boolean"}, result

    it "converts table type", ->
      result = to_json_schema\transform types.table
      assert.same {type: "object"}, result

    it "converts array type", ->
      result = to_json_schema\transform types.array
      assert.same {type: "array"}, result

    it "converts nil type", ->
      result = to_json_schema\transform types.nil
      assert.same {type: "null"}, result

    it "converts any type", ->
      result = to_json_schema\transform types.any
      assert.same {}, result

