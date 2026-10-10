local unpack = unpack or table.unpack
local types, BaseType, FailedTransform
do
  local _obj_0 = require("tableshape")
  types, BaseType, FailedTransform = _obj_0.types, _obj_0.BaseType, _obj_0.FailedTransform
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
  local num_positional = #positional_types
  return function(...)
    local args = {
      ...
    }
    local select_count = select("#", ...)
    local transformed_args = { }
    for i, expected_type in ipairs(positional_types) do
      local transformed_value, err = expected_type:_transform(args[i])
      if transformed_value == FailedTransform then
        local error_msg = "argument " .. tostring(i) .. ": " .. tostring(err)
        if assert_on_error then
          error(error_msg)
        else
          return nil, error_msg
        end
      end
      transformed_args[i] = transformed_value
    end
    if rest_type and select_count > num_positional then
      for i = num_positional + 1, select_count do
        local transformed_value, err = rest_type:_transform(args[i])
        if transformed_value == FailedTransform then
          local error_msg = "argument " .. tostring(i) .. " (rest): " .. tostring(err)
          if assert_on_error then
            error(error_msg)
          else
            return nil, error_msg
          end
        end
        transformed_args[i] = transformed_value
      end
    elseif select_count > num_positional then
      for i = num_positional + 1, select_count do
        transformed_args[i] = args[i]
      end
    end
    return fn(unpack(transformed_args, 1, math.max(select_count, num_positional)))
  end
end
return {
  with_args = with_args
}
