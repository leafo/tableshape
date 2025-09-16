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

  describe "shape types", ->
    it "converts basic shape #ddd", ->
      user_shape = types.shape {
        name: types.string
        age: types.number
      }
      result = assert to_json_schema\transform user_shape

      expected = {
        type: "object"
        properties: {
          name: {type: "string"}
          age: {type: "number"}
        }
        required: {"name", "age"}
        additionalProperties: false
      }
      assert.same expected, result

    it "converts shape with optional fields", ->
      user_shape = types.shape {
        name: types.string
        email: types.string\is_optional!
      }
      result = to_json_schema\transform user_shape

      expected = {
        type: "object"
        properties: {
          name: {type: "string"}
          email: {type: {"string", "null"}}
        }
        required: {"name"}
        additionalProperties: false
      }
      assert.same expected, result

    it "converts open shape", ->
      open_shape = types.partial {
        name: types.string
      }
      result = to_json_schema\transform open_shape

      expected = {
        type: "object"
        properties: {
          name: {type: "string"}
        }
        required: {"name"}
      }
      assert.same expected, result

  -- describe "array types", ->
  --   it "converts array_of string", ->
  --     array_type = types.array_of types.string
  --     schema = json_schema array_type
  --     result = schema\transform!
  --     
  --     expected = {
  --       type: "array"
  --       items: {type: "string"}
  --     }
  --     assert.same expected, result

  --   it "converts array_of shape", ->
  --     item_shape = types.shape {
  --       id: types.number
  --       name: types.string
  --     }
  --     array_type = types.array_of item_shape
  --     schema = json_schema array_type
  --     result = schema\transform!
  --     
  --     expected = {
  --       type: "array"
  --       items: {
  --         type: "object"
  --         properties: {
  --           id: {type: "number"}
  --           name: {type: "string"}
  --         }
  --         required: {"id", "name"}
  --         additionalProperties: false
  --       }
  --     }
  --     assert.same expected, result

  --   it "converts array_contains", ->
  --     contains_type = types.array_contains types.string
  --     schema = json_schema contains_type
  --     result = schema\transform!
  --     
  --     expected = {
  --       type: "array"
  --       contains: {type: "string"}
  --     }
  --     assert.same expected, result

  -- describe "composition types", ->
  --   it "converts one_of (anyOf)", ->
  --     one_of_type = types.string + types.number
  --     schema = json_schema one_of_type
  --     result = schema\transform!
  --     
  --     expected = {
  --       anyOf: {
  --         {type: "string"}
  --         {type: "number"}
  --       }
  --     }
  --     assert.same expected, result

  --   it "converts all_of (allOf)", ->
  --     all_of_type = types.string * types.pattern("^hello")
  --     schema = json_schema all_of_type
  --     result = schema\transform!
  --     
  --     expected = {
  --       allOf: {
  --         {type: "string"}
  --         {type: "string", pattern: "^hello"}
  --       }
  --     }
  --     assert.same expected, result

  -- describe "pattern types", ->
  --   it "converts pattern", ->
  --     pattern_type = types.pattern "^[a-z]+$"
  --     schema = json_schema pattern_type
  --     result = schema\transform!
  --     
  --     expected = {
  --       type: "string"
  --       pattern: "^[a-z]+$"
  --     }
  --     assert.same expected, result

  -- describe "literal types", ->
  --   it "converts string literal", ->
  --     literal_type = types.literal "hello"
  --     schema = json_schema literal_type
  --     result = schema\transform!
  --     
  --     expected = {
  --       const: "hello"
  --     }
  --     assert.same expected, result

  --   it "converts number literal", ->
  --     literal_type = types.literal 42
  --     schema = json_schema literal_type
  --     result = schema\transform!
  --     
  --     expected = {
  --       const: 42
  --     }
  --     assert.same expected, result

  -- describe "range types", ->
  --   it "converts numeric range", ->
  --     range_type = types.range 1, 10
  --     schema = json_schema range_type
  --     result = schema\transform!
  --     
  --     expected = {
  --       type: "number"
  --       minimum: 1
  --       maximum: 10
  --     }
  --     assert.same expected, result

  -- describe "map types", ->
  --   it "converts map_of", ->
  --     map_type = types.map_of types.string, types.number
  --     schema = json_schema map_type
  --     result = schema\transform!
  --     
  --     expected = {
  --       type: "object"
  --       additionalProperties: {type: "number"}
  --     }
  --     assert.same expected, result

  -- describe "transform types", ->
  --   it "handles transform nodes", ->
  --     transform_type = types.string / (s) -> s\upper!
  --     schema = json_schema transform_type
  --     result = schema\transform!
  --     
  --     expected = {
  --       type: "string"
  --     }
  --     assert.same expected, result

  -- describe "complex nested structures", ->
  --   it "converts complex nested shape", ->
  --     complex_shape = types.shape {
  --       user: types.shape {
  --         id: types.number
  --         profile: types.shape {
  --           name: types.string
  --           age: types.number\is_optional!
  --         }
  --       }
  --       posts: types.array_of types.shape {
  --         id: types.number
  --         title: types.string
  --         tags: types.array_of(types.string)\is_optional!
  --       }
  --       metadata: types.any\is_optional!
  --     }
  --     
  --     schema = json_schema complex_shape
  --     result = schema\transform!
  --     
  --     expected = {
  --       type: "object"
  --       properties: {
  --         user: {
  --           type: "object"
  --           properties: {
  --             id: {type: "number"}
  --             profile: {
  --               type: "object"
  --               properties: {
  --                 name: {type: "string"}
  --                 age: {type: {"number", "null"}}
  --               }
  --               required: {"name"}
  --               additionalProperties: false
  --             }
  --           }
  --           required: {"id", "profile"}
  --           additionalProperties: false
  --         }
  --         posts: {
  --           type: "array"
  --           items: {
  --             type: "object"
  --             properties: {
  --               id: {type: "number"}
  --               title: {type: "string"}
  --               tags: {
  --                 type: {"array", "null"}
  --                 items: {type: "string"}
  --               }
  --             }
  --             required: {"id", "title"}
  --             additionalProperties: false
  --           }
  --         }
  --         metadata: {}
  --       }
  --       required: {"user", "posts"}
  --       additionalProperties: false
  --     }
  --     assert.same expected, result



  -- describe "optional types", ->
  --   it "converts optional string", ->
  --     schema = json_schema types.string\is_optional!
  --     result = schema\transform!
  --     assert.same {type: {"string", "null"}}, result

  --   it "converts optional number", ->
  --     schema = json_schema types.number\is_optional!
  --     result = schema\transform!
  --     assert.same {type: {"number", "null"}}, result

