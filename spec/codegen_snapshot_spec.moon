-- codegen output verification 
-- 
-- To regenerate after an intentional codegen change:
--   UPDATE_SNAPSHOTS=1 busted
-- then review the diff in spec/snapshots/ like any other change.
--
-- Only statically compilable types are used: generate_module rejects schemas
-- that embed lua functions (transforms, custom, function tags) since a
-- standalone module can't carry runtime references.

import types from require "tableshape"
import generate_module from require "tableshape.codegen"

SNAPSHOT_DIR = "spec/snapshots/"

read_file = (path) ->
  fh = io.open path, "r"
  return nil unless fh
  with contents = fh\read "*a"
    fh\close!

write_file = (path, contents) ->
  fh = assert io.open(path, "w"), "could not open #{path} for writing"
  fh\write contents
  fh\close!

-- name -> statically compilable type. The name maps to
-- spec/snapshots/<name>.lua; keep names stable so goldens track their type.
-- Each case is chosen to exercise a distinct branch of the compiler.
snapshots = {
  {"closed_shape", types.shape { id: types.number, name: types.string, active: types.boolean }}
  {"tagged_shape", types.shape { id: types.number, name: types.string\tag "name" }}
  {"open_shape", types.shape { id: types.number }, open: true}
  {"open_shape_tagged", types.shape { name: types.string\tag "n" }, open: true}
  {"extra_fields_pure", types.shape {}, extra_fields: types.map_of types.string, types.string}
  {"extra_fields_tagged", types.shape {}, extra_fields: types.map_of types.string, types.any\tag "vals[]"}
  {"map_of_pure", types.map_of types.string, types.number}
  {"map_of_tagged", types.map_of types.string, types.any\tag "vals[]"}
  {"one_of_hash", types.one_of {"a", "b", "c"}}
  {"one_of_types", types.one_of {types.string, types.number}}
  {"array_of", types.array_of types.string}
  {"array_contains", types.array_contains types.number}
  {"nested_shape", types.shape { user: types.shape { id: types.number }, tags: types.array_of types.string }}
  {"range", types.range 1, 10}
  {"pattern", types.pattern "^%d+$"}
}

describe "tableshape.codegen snapshots", ->
  updating = os.getenv "UPDATE_SNAPSHOTS"

  for {name, node} in *snapshots
    it "#{name}", ->
      generated = generate_module node
      path = SNAPSHOT_DIR .. name .. ".lua"

      if updating
        write_file path, generated
      else
        expected = read_file path
        assert.truthy expected,
          "missing snapshot #{path} -- run UPDATE_SNAPSHOTS=1 busted to create it"
        assert.same expected, generated
