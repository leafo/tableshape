local unpack = unpack or table.unpack
local types, BaseType
do
  local _obj_0 = require("tableshape")
  types, BaseType = _obj_0.types, _obj_0.BaseType
end
local with_args
with_args = function(arg_types, fn)
  assert(type(arg_types) == "table", "with_args expects table for first argument")
  assert(type(fn) == "function", "with_args expects function for second argument")
  local assert_on_error, rest_type, positional_types
  if arg_types.assert ~= nil then
    assert_on_error = arg_types.assert
  end
  if arg_types.rest then
    if BaseType:is_base_type(arg_types.rest) then
      rest_type = arg_types.rest
    else
      rest_type = types.literal(arg_types.rest)
    end
  end
  positional_types = { }
  for i, arg_type in ipairs(arg_types) do
    if BaseType:is_base_type(arg_type) then
      table.insert(positional_types, arg_type)
    else
      table.insert(positional_types, types.literal(arg_type))
    end
  end
  return function(...)
    local args = {
      ...
    }
    local select_count = select("#", ...)
    local transformed_args = { }
    for i, expected_type in ipairs(positional_types) do
      local arg_value = args[i]
      local transformed_value, err = expected_type:transform(arg_value)
      if transformed_value == nil and err then
        local error_msg = "argument " .. tostring(i) .. ": " .. tostring(err)
        if assert_on_error then
          error(error_msg)
        else
          return nil, error_msg
        end
      else
        transformed_args[i] = transformed_value
      end
    end
    if rest_type and select_count > #positional_types then
      for i = #positional_types + 1, select_count do
        local arg_value = args[i]
        local transformed_value, err = rest_type:transform(arg_value)
        if transformed_value == nil and err then
          local error_msg = "argument " .. tostring(i) .. " (rest): " .. tostring(err)
          if assert_on_error then
            error(error_msg)
          else
            return nil, error_msg
          end
        else
          transformed_args[i] = transformed_value
        end
      end
    elseif select_count > #positional_types then
      for i = #positional_types + 1, select_count do
        transformed_args[i] = args[i]
      end
    end
    return fn(unpack(transformed_args, 1, select_count))
  end
end
return {
  with_args = with_args
}
