
-- this installs luassert assertion and formatter for tableshape types

say = require "say"
assert = require "luassert"

say\set "assertion.shape.positive",
  "Expected %s to match shape:\n%s"

say\set "assertion.shape.negative",
  "Expected %s to not match shape:\n%s"

assert\register(
  "assertion",
  "shape"

  (state, arguments) ->
    { input, expected } = arguments
    assert is_type(expected), "Expected tableshape type for second argument to assert.shape"
    if expected input
      true
    else
      false

  "assertion.shape.positive"
  "assertion.shape.negative"
)

assert\add_formatter (v) ->
  if is_type v
    return tostring v

true
