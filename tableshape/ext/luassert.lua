local is_type
is_type = require("tableshape").is_type
local say = require("say")
local assert = require("luassert")
say:set("assertion.shape.positive", "Expected %s to match shape:\n%s")
say:set("assertion.shape.negative", "Expected %s to not match shape:\n%s")
assert:register("assertion", "shape", function(state, arguments)
  local input, expected
  input, expected = arguments[1], arguments[2]
  assert(is_type(expected), "Expected tableshape type for second argument to assert.shape")
  if expected(input) then
    return true
  else
    return false
  end
end, "assertion.shape.positive", "assertion.shape.negative")
assert:add_formatter(function(v)
  if is_type(v) then
    return tostring(v)
  end
end)
return true
