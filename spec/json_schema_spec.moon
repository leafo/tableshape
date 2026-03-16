import to_json_schema, simplify, JsonSchema from require "tableshape.json_schema"
import types from require "tableshape"

describe "tableshape.json_schema", ->
  describe "simplify", ->
    it "passes through plain string", ->
      result = simplify\transform "hello"
      assert.same "hello", result

    it "passes through plain number", ->
      result = simplify\transform 42
      assert.same 42, result

    it "passes through plain boolean", ->
      result = simplify\transform true
      assert.same true, result

    it "extracts value from types.literal string", ->
      result = simplify\transform types.literal "hello"
      assert.same "hello", result

    it "extracts value from types.literal number", ->
      result = simplify\transform types.literal 99
      assert.same 99, result

    it "extracts value from types.literal boolean", ->
      result = simplify\transform types.literal false
      assert.same false, result

    it "strips describe node", ->
      input = types.string\describe "a name"
      result = simplify\transform input
      assert.same types.string, result

    it "strips annotate node", ->
      input = types.annotate types.string
      result = simplify\transform input
      assert.same types.string, result

    it "strips tagged type node", ->
      input = types.string\tag "my_tag"
      result = simplify\transform input
      assert.same types.string, result

    it "strips scope node", ->
      input = types.scope types.string
      result = simplify\transform input
      assert.same types.string, result

    it "strips nested describe and tag", ->
      input = types.string\describe("a name")\tag "my_tag"
      result = simplify\transform input
      assert.same types.string, result

    it "strips annotate wrapping describe wrapping tag", ->
      input = types.annotate types.string\describe("my string")\tag "fart"
      result = simplify\transform input
      assert.same types.string, result

    it "strips describe wrapping annotate", ->
      input = types.annotate(types.number)\describe "count"
      result = simplify\transform input
      assert.same types.number, result

    it "extracts literal value through wrapper nodes", ->
      input = types.literal("yes")\describe("a flag")\tag "answer"
      result = simplify\transform input
      assert.same "yes", result

    it "returns nil for unsupported type", ->
      input = types.userdata
      result = simplify\transform input
      assert.is_nil result

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

  describe "JsonSchema wrapper", ->
    it "emits the provided schema directly", ->
      result = to_json_schema\transform JsonSchema types.string, {
        type: "string"
        format: "email"
      }

      assert.same {
        type: "string"
        format: "email"
      }, result

    it "emits the schema returned from a function", ->
      result = to_json_schema\transform JsonSchema types.string, (base_type) ->
        assert.same types.string, base_type
        {
          type: "string"
          format: "email"
        }

      assert.same {
        type: "string"
        format: "email"
      }, result

    it "passes the wrapped type to the schema function", ->
      wrapped_type = types.shape {
        id: types.number
      }

      result = to_json_schema\transform JsonSchema wrapped_type, (base_type) ->
        assert.same wrapped_type, base_type
        {
          type: "object"
          title: "wrapped"
        }

      assert.same {
        type: "object"
        title: "wrapped"
      }, result

    it "does not recurse into the wrapped type for schema generation", ->
      result = to_json_schema\transform JsonSchema types.userdata, {
        type: "string"
      }

      assert.same {
        type: "string"
      }, result

    it "still validates like the wrapped type", ->
      wrapped = JsonSchema types.number, {
        type: "integer"
      }

      assert.same 42, wrapped\transform 42
      assert.is_nil wrapped\transform "nope"

    it "works in shape fields", ->
      result = to_json_schema\transform types.shape {
        email: JsonSchema types.string, {
          type: "string"
          format: "email"
        }
      }

      assert.same {
        type: "object"
        properties: {
          email: {
            type: "string"
            format: "email"
          }
        }
        required: {"email"}
        additionalProperties: false
      }, result

    it "works in optional shape fields", ->
      result = to_json_schema\transform types.shape {
        email: JsonSchema(types.string, {
          type: "string"
          format: "email"
        })\is_optional!
      }

      assert.same {
        type: "object"
        properties: {
          email: {
            type: "string"
            format: "email"
          }
        }
        required: {}
        additionalProperties: false
      }, result

    it "applies outer description to the emitted schema", ->
      result = to_json_schema\transform JsonSchema(types.string, {
        type: "string"
      })\describe "some text"

      assert.same {
        type: "string"
        description: "some text"
      }, result

    it "does not mutate the provided schema table", ->
      schema = {
        type: "string"
      }

      result = to_json_schema\transform JsonSchema(types.string, schema)\describe "some text"

      assert.same {
        type: "string"
        description: "some text"
      }, result

      assert.same {
        type: "string"
      }, schema

    it "does not mutate the schema returned from a function", ->
      schema = {
        type: "string"
      }

      result = to_json_schema\transform JsonSchema(types.string, (base_type) ->
        assert.same types.string, base_type
        schema
      )\describe "some text"

      assert.same {
        type: "string"
        description: "some text"
      }, result

      assert.same {
        type: "string"
      }, schema

  describe "shape types", ->
    it "converts basic shape", ->
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
        required: {"age", "name"}
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
          email: {type: "string"}
        }
        required: {"name"}
        additionalProperties: false
      }
      assert.same expected, result

    it "converts shape with optional described fields", ->
      user_shape = types.shape {
        name: types.string
        email: types.string\describe("an email")\is_optional!
        age: types.number\is_optional!\describe("user age")
      }
      result = to_json_schema\transform user_shape

      expected = {
        type: "object"
        properties: {
          name: {type: "string"}
          email: {type: "string", description: "an email"}
          age: {type: "number", description: "user age"}
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

      assert.same {
        type: "object"
        properties: {
          name: {type: "string"}
        }
        required: {"name"}
      }, result

    it "converts a shape with description", ->
      some_shape = types.shape({
        hello: types.string\describe "poop"
        zone: types.annotate types.number\is_optional!
        status: types.one_of({"cool", "bad"})\describe "please pick"
      })\describe "my dodo"

      result = to_json_schema\transform some_shape

      assert.same {
        type: "object"
        additionalProperties: false
        description: "my dodo"
        properties: {
          hello: {
            description: "poop"
            type: "string"
          }
          zone: {
            type: "number"
          }
          status: {
            type: "string"
            enum: {"cool", "bad"}
            description: "please pick"
          }
        }
        required: {"hello", "status"}
      }, result


  describe "array types", ->
    it "converts array_of string", ->
      array_type = types.array_of types.string
      result = to_json_schema\transform array_type

      assert.same {
        type: "array"
        items: {type: "string"}
      }, result

    it "converts array_of string with ranged length", ->
      array_type = types.array_of types.string, length: types.range 1, 3
      result = to_json_schema\transform array_type

      assert.same {
        type: "array"
        items: {type: "string"}
        minItems: 1
        maxItems: 3
      }, result

    it "converts array_of string with fixed length", ->
      array_type = types.array_of types.string, length: 2
      result = to_json_schema\transform array_type

      assert.same {
        type: "array"
        items: {type: "string"}
        minItems: 2
        maxItems: 2
      }, result

    it "converts array_of shape", ->
      array_type = types.array_of types.shape {
        id: types.number
        name: types.string
      }
      result = to_json_schema\transform array_type

      assert.same {
        type: "array"
        items: {
          type: "object"
          properties: {
            id: {type: "number"}
            name: {type: "string"}
          }
          required: {"id", "name"}
          additionalProperties: false
        }
      }, result

    it "converts a shape with array_of string field", ->
      shape_type = types.shape {
        name: types.string
        tags: types.array_of types.string
      }
      result = to_json_schema\transform shape_type

      assert.same {
        type: "object"
        properties: {
          name: {type: "string"}
          tags: {
            type: "array"
            items: {type: "string"}
          }
        }
        required: {"name", "tags"}
        additionalProperties: false
      }, result

    it "converts a shape with ranged array_of string field", ->
      shape_type = types.shape {
        tags: types.array_of types.string, length: types.range 1, 3
      }
      result = to_json_schema\transform shape_type

      assert.same {
        type: "object"
        properties: {
          tags: {
            type: "array"
            items: {type: "string"}
            minItems: 1
            maxItems: 3
          }
        }
        required: {"tags"}
        additionalProperties: false
      }, result

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
  describe "map types", ->
    it "converts map_of with string keys", ->
      result = to_json_schema\transform types.map_of types.string, types.number

      assert.same {
        type: "object"
        additionalProperties: {type: "number"}
      }, result

    it "converts map_of with wrapped string keys", ->
      map_type = types.map_of types.string\describe("a key"), types.number
      result = to_json_schema\transform map_type

      assert.same {
        type: "object"
        additionalProperties: {type: "number"}
      }, result

    it "converts map_of in shape field", ->
      shape_type = types.shape {
        metadata: types.map_of types.string, types.number
      }
      result = to_json_schema\transform shape_type

      assert.same {
        type: "object"
        properties: {
          metadata: {
            type: "object"
            additionalProperties: {type: "number"}
          }
        }
        required: {"metadata"}
        additionalProperties: false
      }, result

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

  describe "literal types", ->
    it "converts string literal", ->
      result = to_json_schema\transform types.literal "hello"
      assert.same {const: "hello"}, result

    it "converts number literal", ->
      result = to_json_schema\transform types.literal 42
      assert.same {const: 42}, result

    it "converts boolean literal", ->
      result = to_json_schema\transform types.literal true
      assert.same {const: true}, result

    it "converts plain string value", ->
      result = to_json_schema\transform "fixed_value"
      assert.same {const: "fixed_value"}, result

    it "converts plain number value", ->
      result = to_json_schema\transform 99
      assert.same {const: 99}, result

    it "converts plain boolean value", ->
      result = to_json_schema\transform false
      assert.same {const: false}, result

    it "converts literal in shape field", ->
      s = types.shape {
        status: types.literal "active"
        count: types.literal 5
      }
      result = to_json_schema\transform s
      expected = {
        type: "object"
        properties: {
          status: {const: "active"}
          count: {const: 5}
        }
        required: {"count", "status"}
        additionalProperties: false
      }
      assert.same expected, result

  describe "enum types", ->
    it "converts one_of with string literals", ->
      result = to_json_schema\transform types.one_of {"red", "green", "blue"}
      assert.same {type: "string", enum: {"red", "green", "blue"}}, result

    it "converts one_of with number literals", ->
      result = to_json_schema\transform types.one_of {1, 2, 3}
      assert.same {type: "number", enum: {1, 2, 3}}, result

    it "converts one_of with types.literal string values", ->
      result = to_json_schema\transform types.one_of {
        types.literal "active"
        types.literal "inactive"
        types.literal "pending"
      }
      assert.same {type: "string", enum: {"active", "inactive", "pending"}}, result

    it "converts one_of with types.literal number values", ->
      result = to_json_schema\transform types.one_of {
        types.literal 10
        types.literal 20
        types.literal 30
      }
      assert.same {type: "number", enum: {10, 20, 30}}, result

    it "converts enum in shape field", ->
      s = types.shape {
        color: types.one_of {"red", "green", "blue"}
        priority: types.one_of {1, 2, 3}
      }
      result = to_json_schema\transform s
      expected = {
        type: "object"
        properties: {
          color: {type: "string", enum: {"red", "green", "blue"}}
          priority: {type: "number", enum: {1, 2, 3}}
        }
        required: {"color", "priority"}
        additionalProperties: false
      }
      assert.same expected, result

    it "converts described enum", ->
      result = to_json_schema\transform types.one_of({"a", "b", "c"})\describe "pick a letter"
      assert.same {type: "string", enum: {"a", "b", "c"}, description: "pick a letter"}, result

  describe "describe nodes", ->
    it "converts boolean with description", ->
      result = to_json_schema\transform types.boolean\describe "a flag"
      assert.same {type: "boolean", description: "a flag"}, result

    it "converts string with description", ->
      result = to_json_schema\transform types.string\describe "user name"
      assert.same {type: "string", description: "user name"}, result

    it "converts number with description", ->
      result = to_json_schema\transform types.number\describe "the count"
      assert.same {type: "number", description: "the count"}, result

  describe "lapis", ->
    local model, types
    before_each ->
      model = require "lapis.db.base_model"
      types = require "lapis.validate.types"

    it "converts db_id to json schema", ->
      assert.same {
        type: "number"
        description: "database ID integer"
      }, to_json_schema\transform types.db_id

    it "converts enum to json schema", ->
      statuses = model.enum {
        default: 1
        banned: 2
        deleted: 3
      }

      statuses_t = types.db_enum statuses
      assert.same {
        type: "string"
        description: "enum(default, banned, deleted)"
        enum: {
          "default"
          "banned"
          "deleted"
        }
      }, to_json_schema\transform statuses_t

    it "converts valid_text to json schema", ->
      assert.same {
        type: "string"
        description: "valid text"
      }, to_json_schema\transform types.valid_text

    it "converts cleaned_text to json schema", ->
      assert.same {
        type: "string"
        description: "text"
      }, to_json_schema\transform types.cleaned_text

    it "converts empty to json schema", ->
      assert.same {
        type: "null"
        description: "empty"
      }, to_json_schema\transform types.empty

    it "converts empty + valid_text to optional pattern", ->
      assert.same {
        type: "object"
        additionalProperties: false
        required: {}
        properties: {
          blurb: {
            type: "string"
          }
        }
      }, to_json_schema\transform types.shape {
        blurb: types.empty + types.valid_text
      }

    it "converts trimmed_text to json schema", ->
      assert.same {
        type: "string"
        description: "valid text"
      }, to_json_schema\transform types.trimmed_text

    it "converts truncated_text to json schema", ->
      assert.same {
        type: "string"
        description: "valid text"
      }, to_json_schema\transform types.truncated_text 10

    it "converts limited_text to json schema", ->
      assert.same {
        type: "string"
        description: "text between 1 and 20 characters"
      }, to_json_schema\transform types.limited_text 20

    it "converts limited_text with minimum length to json schema", ->
      assert.same {
        type: "string"
        description: "text between 5 and 20 characters"
      }, to_json_schema\transform types.limited_text 20, 5
