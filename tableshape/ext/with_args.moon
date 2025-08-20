
import types, BaseType from require "tableshape"

with_args = (arg_types, fn) ->
  assert type(arg_types) == "table", "with_args expects table for first argument"
  assert type(fn) == "function", "with_args expects function for second argument"

  -- Extract options from arg_types
  local assert_on_error, rest_type, positional_types

  if arg_types.assert != nil
    assert_on_error = arg_types.assert

  if arg_types.rest
    rest_type = if BaseType\is_base_type arg_types.rest
      arg_types.rest
    else
      types.literal arg_types.rest

  -- Get positional argument types (non-string keys) and convert literals to types
  positional_types = {}
  for i, arg_type in ipairs arg_types
    if BaseType\is_base_type arg_type
      table.insert positional_types, arg_type
    else
      table.insert positional_types, types.literal arg_type

  (...) ->
    args = {...}
    select_count = select "#", ...

    -- Validate positional arguments
    transformed_args = {}
    for i, expected_type in ipairs positional_types
      arg_value = args[i]

      -- Transform/validate the argument (all are now BaseTypes)
      transformed_value, err = expected_type\transform arg_value
      if transformed_value == nil and err
        error_msg = "argument #{i}: #{err}"
        if assert_on_error
          error error_msg
        else
          return nil, error_msg
      else
        transformed_args[i] = transformed_value

    -- Handle rest arguments if rest type is specified
    if rest_type and select_count > #positional_types
      for i = #positional_types + 1, select_count
        arg_value = args[i]

        -- Transform/validate rest argument (now always a BaseType)
        transformed_value, err = rest_type\transform arg_value
        if transformed_value == nil and err
          error_msg = "argument #{i} (rest): #{err}"
          if assert_on_error
            error error_msg
          else
            return nil, error_msg
        else
          transformed_args[i] = transformed_value

    -- If no rest type specified but extra args provided, copy them as-is
    elseif select_count > #positional_types
      for i = #positional_types + 1, select_count
        transformed_args[i] = args[i]

    -- Call the original function with validated/transformed arguments
    fn unpack transformed_args, 1, select_count

{:with_args}
