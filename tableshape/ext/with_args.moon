
unpack = unpack or table.unpack

import types, BaseType, FailedTransform from require "tableshape"

with_args = (arg_types, fn) ->
  assert type(arg_types) == "table", "with_args expects table for first argument"
  assert type(fn) == "function", "with_args expects function for second argument"

  local assert_on_error, rest_type, positional_types

  if arg_types.assert != nil
    assert_on_error = arg_types.assert

  if arg_types.rest
    rest_type = if BaseType\is_base_type arg_types.rest
      arg_types.rest
    else
      types.literal arg_types.rest

  positional_types = {}
  for i, arg_type in ipairs arg_types
    if BaseType\is_base_type arg_type
      table.insert positional_types, arg_type
    else
      table.insert positional_types, types.literal arg_type

  num_positional = #positional_types

  (...) ->
    args = {...}
    select_count = select "#", ...

    transformed_args = {}
    for i, expected_type in ipairs positional_types
      transformed_value, err = expected_type\_transform args[i]
      if transformed_value == FailedTransform
        error_msg = "argument #{i}: #{err}"
        if assert_on_error
          error error_msg
        else
          return nil, error_msg

      transformed_args[i] = transformed_value

    if rest_type and select_count > num_positional
      for i = num_positional + 1, select_count
        transformed_value, err = rest_type\_transform args[i]
        if transformed_value == FailedTransform
          error_msg = "argument #{i} (rest): #{err}"
          if assert_on_error
            error error_msg
          else
            return nil, error_msg

        transformed_args[i] = transformed_value
    elseif select_count > num_positional
      for i = num_positional + 1, select_count
        transformed_args[i] = args[i]

    -- a positional type may produce a value for an argument the caller
    -- omitted, so the call can't be cut off at the caller's argument count
    fn unpack transformed_args, 1, math.max select_count, num_positional

{:with_args}
