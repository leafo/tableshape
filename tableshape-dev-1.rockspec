package = "tableshape"
version = "dev-1"

source = {
  url = "git://github.com/leafo/tableshape.git",
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
  }
}

