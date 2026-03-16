package = "tableshape"
version = "dev-1"

source = {
  url = "git+https://github.com/leafo/tableshape.git",
}

description = {
  summary = "Test the shape or structure of a Lua table",
  homepage = "https://github.com/leafo/tableshape",
  license = "MIT"
}

dependencies = {
  "lua >= 5.1"
}

build = {
  type = "builtin",
  modules = {
    ["tableshape"] = "tableshape/init.lua",
    ["tableshape.ext.luassert"] = "tableshape/ext/luassert.lua",
    ["tableshape.moonscript"] = "tableshape/moonscript.lua",
    ["tableshape.ext.json_schema"] = "tableshape/ext/json_schema.lua",
  }
}
