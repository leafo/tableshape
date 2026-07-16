local types, BaseType, FailedTransform
do
  local _obj_0 = require("tableshape")
  types, BaseType, FailedTransform = _obj_0.types, _obj_0.BaseType, _obj_0.FailedTransform
end
local load_code = loadstring or load
local clone_state
clone_state = function(state_obj)
  if type(state_obj) ~= "table" then
    return { }
  end
  local out
  do
    local _tbl_0 = { }
    for k, v in pairs(state_obj) do
      _tbl_0[k] = v
    end
    out = _tbl_0
  end
  do
    local mt = getmetatable(state_obj)
    if mt then
      setmetatable(out, mt)
    end
  end
  return out
end
local CLONE_STATE_SOURCE = [[local clone_state = function(state_obj)
if type(state_obj) ~= "table" then return {} end
local out = {}
for k, v in pairs(state_obj) do out[k] = v end
local mt = getmetatable(state_obj)
if mt then setmetatable(out, mt) end
return out
end]]
local SORTED_PAIRS_SOURCE = [[local sorted_pairs = function(t)
local keys = {}
for k in pairs(t) do keys[#keys + 1] = k end
table.sort(keys, function(a, b)
local ta, tb = type(a), type(b)
if ta ~= tb then return ta < tb end
if ta == "number" or ta == "string" then return a < b end
if ta == "boolean" then return not a and b end
return tostring(a) < tostring(b)
end)
local i = 0
return function()
i = i + 1
local k = keys[i]
if k ~= nil then return k, t[k] end
end
end]]
local sorted_pairs
sorted_pairs = function(t)
  local keys
  do
    local _accum_0 = { }
    local _len_0 = 1
    for k in pairs(t) do
      _accum_0[_len_0] = k
      _len_0 = _len_0 + 1
    end
    keys = _accum_0
  end
  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then
      return ta < tb
    else
      local _exp_0 = ta
      if "number" == _exp_0 or "string" == _exp_0 then
        return a < b
      elseif "boolean" == _exp_0 then
        return not a and b
      else
        return tostring(a) < tostring(b)
      end
    end
  end)
  local i = 0
  return function()
    i = i + 1
    local k = keys[i]
    if not (k == nil) then
      return k, t[k]
    end
  end
end
local Type = types.string.__class
local AnyType = types.any.__class
local ArrayType = types.array.__class
local CloneType = types.clone.__class
local NotType = (-types.any).__class
local Literal = types.literal
local OneOf = types.one_of
local AllOf = types.all_of
local Shape = types.shape
local Partial = types.partial
local Pattern = types.pattern
local ArrayOf = types.array_of
local ArrayContains = types.array_contains
local MapOf = types.map_of
local Range = types.range
local Custom = types.custom
local TagScopeType = types.scope
local Proxy = types.proxy
local AnnotateNode = types.annotate
local DescribeNode = types.describe
local OptionalType = types.optional
local TransformNode = types._transform
local TaggedType = types._tagged_type
local SequenceNode = types._sequence
local FirstOfNode = types._first_of
local Compiler
do
  local _class_0
  local _base_0 = {
    handlers = {
      [AnyType] = "compile_any",
      [Literal] = "compile_literal",
      [Type] = "compile_type",
      [OneOf] = "compile_one_of",
      [AllOf] = "compile_all_of",
      [SequenceNode] = "compile_sequence",
      [FirstOfNode] = "compile_first_of",
      [TransformNode] = "compile_transform",
      [OptionalType] = "compile_optional",
      [NotType] = "compile_not",
      [TaggedType] = "compile_tagged",
      [TagScopeType] = "compile_scope",
      [Shape] = "compile_shape",
      [Partial] = "compile_shape",
      [ArrayType] = "compile_array",
      [ArrayOf] = "compile_array_of",
      [ArrayContains] = "compile_array_contains",
      [MapOf] = "compile_map_of",
      [Range] = "compile_range",
      [Pattern] = "compile_pattern",
      [Custom] = "compile_custom",
      [CloneType] = "compile_clone",
      [Proxy] = "compile_proxy"
    },
    push = function(self, line)
      return table.insert(self.lines, line)
    end,
    current_node_description = function(self)
      local node = self.node_stack[#self.node_stack]
      if not (node) then
        return "<unknown type>"
      end
      local ok, description = pcall(function()
        return node:_describe()
      end)
      if ok and description then
        return description
      else
        return tostring(node)
      end
    end,
    ref = function(self, val)
      if self.static then
        error("static compile: " .. tostring(self:current_node_description()) .. " requires a runtime reference (" .. tostring(tostring(val)) .. ")")
      end
      local name = self.ref_ids[val]
      if not (name) then
        table.insert(self.refs, val)
        name = "r" .. tostring(#self.refs)
        self.ref_ids[val] = name
      end
      return name
    end,
    number_expr = function(self, val)
      if val ~= val then
        return "(0/0)"
      end
      if val == math.huge then
        return "math.huge"
      end
      if val == -math.huge then
        return "-math.huge"
      end
      local s = tostring(val)
      if tonumber(s) == val then
        return s
      end
      s = ("%.17g"):format(val)
      if tonumber(s) == val then
        return s
      end
    end,
    value_expr = function(self, val)
      local _exp_0 = type(val)
      if "string" == _exp_0 then
        return ("%q"):format(val)
      elseif "boolean" == _exp_0 or "nil" == _exp_0 then
        return tostring(val)
      elseif "number" == _exp_0 then
        return self:number_expr(val) or self:ref(val)
      else
        return self:ref(val)
      end
    end,
    data_expr = function(self, val, seen)
      if seen == nil then
        seen = { }
      end
      if getmetatable(val) then
        return nil
      end
      if seen[val] then
        return nil
      end
      seen[val] = true
      local parts = { }
      local array_len = 0
      for i, item in ipairs(val) do
        local expr = self:data_item_expr(item, seen)
        if not (expr) then
          return nil
        end
        table.insert(parts, expr)
        array_len = i
      end
      for k, v in sorted_pairs(val) do
        local _continue_0 = false
        repeat
          if type(k) == "number" and k >= 1 and k <= array_len and k % 1 == 0 then
            _continue_0 = true
            break
          end
          local key = self:data_item_expr(k, seen)
          if not (key) then
            return nil
          end
          local item = self:data_item_expr(v, seen)
          if not (item) then
            return nil
          end
          table.insert(parts, "[" .. tostring(key) .. "] = " .. tostring(item))
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      seen[val] = nil
      return "{" .. tostring(table.concat(parts, ", ")) .. "}"
    end,
    data_item_expr = function(self, val, seen)
      local _exp_0 = type(val)
      if "string" == _exp_0 then
        return ("%q"):format(val)
      elseif "boolean" == _exp_0 then
        return tostring(val)
      elseif "number" == _exp_0 then
        return self:number_expr(val)
      elseif "table" == _exp_0 then
        return self:data_expr(val, seen)
      end
    end,
    const = function(self, val)
      local name = self.const_ids[val]
      if not (name) then
        local expr = self:data_expr(val)
        if not (expr) then
          return self:ref(val)
        end
        table.insert(self.consts, expr)
        name = "c" .. tostring(#self.consts)
        self.const_ids[val] = name
      end
      return name
    end,
    resolve_proxy = function(self, node)
      local inner = self.proxy_cache[node]
      if not (inner) then
        inner = assert(node.fn(), "proxy missing transformer")
        self.proxy_cache[node] = inner
      end
      return inner
    end,
    is_pure = function(self, node)
      local cached = self.pure_cache[node]
      if cached ~= nil then
        return cached, false
      end
      if self.pure_active[node] then
        return true, true
      end
      self.pure_active[node] = true
      local result, provisional = self:compute_pure(node)
      self.pure_active[node] = nil
      if not provisional or result == false then
        self.pure_cache[node] = result
      end
      return result, provisional
    end,
    all_pure = function(self, nodes)
      local provisional = false
      for _index_0 = 1, #nodes do
        local _continue_0 = false
        repeat
          local n = nodes[_index_0]
          if not (BaseType:is_base_type(n)) then
            _continue_0 = true
            break
          end
          local p, prov = self:is_pure(n)
          if not (p) then
            return false, false
          end
          if prov then
            provisional = true
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return true, provisional
    end,
    compute_pure = function(self, node)
      if node._compile_inner then
        return self:is_pure(node:_compile_inner())
      end
      local custom = node._compile_pure
      if custom ~= nil then
        if type(custom) == "function" then
          local result, provisional = node:_compile_pure(self)
          return (result and true or false), (provisional and true or false)
        else
          return (custom and true or false), false
        end
      end
      local _exp_0 = node.__class
      if AnyType == _exp_0 or Literal == _exp_0 or Range == _exp_0 or Custom == _exp_0 or ArrayType == _exp_0 then
        return true, false
      elseif Pattern == _exp_0 then
        return true, false
      elseif NotType == _exp_0 then
        return true, false
      elseif Type == _exp_0 then
        if node.length_type then
          return self:is_pure(node.length_type)
        else
          return true, false
        end
      elseif OneOf == _exp_0 then
        if node.options_hash then
          return true, false
        else
          return self:all_pure(node.options)
        end
      elseif AllOf == _exp_0 then
        return self:all_pure(node.types)
      elseif SequenceNode == _exp_0 then
        return self:all_pure(node.sequence)
      elseif FirstOfNode == _exp_0 then
        return self:all_pure(node.options)
      elseif OptionalType == _exp_0 then
        return self:is_pure(node.base_type)
      elseif DescribeNode == _exp_0 then
        return self:is_pure(node.node)
      elseif AnnotateNode == _exp_0 then
        return self:is_pure(node.base_type)
      elseif Shape == _exp_0 or Partial == _exp_0 then
        local children
        do
          local _accum_0 = { }
          local _len_0 = 1
          for _, v in pairs(node.shape) do
            _accum_0[_len_0] = v
            _len_0 = _len_0 + 1
          end
          children = _accum_0
        end
        if node.extra_fields_type then
          table.insert(children, node.extra_fields_type)
        end
        return self:all_pure(children)
      elseif ArrayOf == _exp_0 then
        local children = {
          node.expected
        }
        if node.length_type then
          table.insert(children, node.length_type)
        end
        return self:all_pure(children)
      elseif ArrayContains == _exp_0 then
        return self:all_pure({
          node.contains
        })
      elseif MapOf == _exp_0 then
        return self:all_pure({
          node.expected_key,
          node.expected_value
        })
      elseif Proxy == _exp_0 then
        return self:is_pure(self:resolve_proxy(node))
      else
        return false, false
      end
    end,
    inline_predicate = function(self, node, v, s)
      table.insert(self.node_stack, node)
      local result = self:build_inline_predicate(node, v, s)
      table.remove(self.node_stack)
      return result
    end,
    build_inline_predicate = function(self, node, v, s)
      if node._compile_inner then
        return self:inline_predicate(node:_compile_inner(), v, s)
      end
      if node._compile_predicate then
        return node:_compile_predicate(self, v, s)
      end
      local _exp_0 = node.__class
      if AnyType == _exp_0 then
        return "true"
      elseif Literal == _exp_0 then
        return tostring(v) .. " == " .. tostring(self:value_expr(node.value))
      elseif Type == _exp_0 then
        local base = "type(" .. tostring(v) .. ") == " .. tostring(self:value_expr(node.t))
        if node.length_type then
          return tostring(base) .. " and " .. tostring(self:predicate_expr(node.length_type, "#" .. tostring(v), s))
        else
          return base
        end
      elseif Range == _exp_0 then
        local vt = self:value_expr(node.value_type.t)
        return "type(" .. tostring(v) .. ") == " .. tostring(vt) .. " and " .. tostring(v) .. " >= " .. tostring(self:value_expr(node.left)) .. " and " .. tostring(v) .. " <= " .. tostring(self:value_expr(node.right))
      elseif Pattern == _exp_0 then
        local pat = self:value_expr(node.pattern)
        if node.coerce then
          if not (BaseType:is_base_type(node.coerce)) then
            return "string_match(tostring(" .. tostring(v) .. "), " .. tostring(pat) .. ") ~= nil"
          end
        else
          return "(type(" .. tostring(v) .. ") == 'string' and string_match(" .. tostring(v) .. ", " .. tostring(pat) .. ") ~= nil)"
        end
      elseif Custom == _exp_0 then
        return "(" .. tostring(self:ref(node.fn)) .. "(" .. tostring(v) .. ", " .. tostring(s) .. "))"
      elseif OneOf == _exp_0 then
        if node.options_hash then
          return tostring(self:const(node.options_hash)) .. "[" .. tostring(v) .. "] ~= nil"
        else
          if #node.options == 0 then
            return "false"
          end
          local parts
          do
            local _accum_0 = { }
            local _len_0 = 1
            local _list_0 = node.options
            for _index_0 = 1, #_list_0 do
              local option = _list_0[_index_0]
              if BaseType:is_base_type(option) then
                _accum_0[_len_0] = "(" .. tostring(self:predicate_expr(option, v, s)) .. ")"
              else
                _accum_0[_len_0] = tostring(v) .. " == " .. tostring(self:value_expr(option))
              end
              _len_0 = _len_0 + 1
            end
            parts = _accum_0
          end
          return "(" .. tostring(table.concat(parts, " or ")) .. ")"
        end
      elseif FirstOfNode == _exp_0 then
        if #node.options == 0 then
          return "false"
        end
        local parts
        do
          local _accum_0 = { }
          local _len_0 = 1
          local _list_0 = node.options
          for _index_0 = 1, #_list_0 do
            local option = _list_0[_index_0]
            _accum_0[_len_0] = "(" .. tostring(self:predicate_expr(option, v, s)) .. ")"
            _len_0 = _len_0 + 1
          end
          parts = _accum_0
        end
        return "(" .. tostring(table.concat(parts, " or ")) .. ")"
      elseif SequenceNode == _exp_0 then
        if #node.sequence == 0 then
          return "true"
        end
        local parts
        do
          local _accum_0 = { }
          local _len_0 = 1
          local _list_0 = node.sequence
          for _index_0 = 1, #_list_0 do
            local child = _list_0[_index_0]
            _accum_0[_len_0] = "(" .. tostring(self:predicate_expr(child, v, s)) .. ")"
            _len_0 = _len_0 + 1
          end
          parts = _accum_0
        end
        return "(" .. tostring(table.concat(parts, " and ")) .. ")"
      elseif AllOf == _exp_0 then
        if #node.types == 0 then
          return "true"
        end
        local parts
        do
          local _accum_0 = { }
          local _len_0 = 1
          local _list_0 = node.types
          for _index_0 = 1, #_list_0 do
            local child = _list_0[_index_0]
            _accum_0[_len_0] = "(" .. tostring(self:predicate_expr(child, v, s)) .. ")"
            _len_0 = _len_0 + 1
          end
          parts = _accum_0
        end
        return "(" .. tostring(table.concat(parts, " and ")) .. ")"
      elseif NotType == _exp_0 then
        return "not (" .. tostring(self:predicate_expr(node.base_type, v, s)) .. ")"
      elseif OptionalType == _exp_0 then
        return "(" .. tostring(v) .. " == nil or (" .. tostring(self:predicate_expr(node.base_type, v, s)) .. "))"
      elseif DescribeNode == _exp_0 then
        return self:inline_predicate(node.node, v, s)
      elseif AnnotateNode == _exp_0 then
        return self:inline_predicate(node.base_type, v, s)
      end
    end,
    predicate_expr = function(self, node, v, s)
      do
        local pred = self:inline_predicate(node, v, s)
        if pred then
          return pred
        else
          return "(" .. tostring(self:compile_node(node)) .. "(" .. tostring(v) .. ", " .. tostring(s) .. ")) ~= FailedTransform"
        end
      end
    end,
    compile_node = function(self, node)
      do
        local name = self.fn_ids[node]
        if name then
          return name
        end
      end
      local cls = node.__class
      if node._compile_inner then
        local name = self:compile_node(node:_compile_inner())
        self.fn_ids[node] = name
        return name
      end
      if cls == DescribeNode then
        local name = self:compile_node(node.node)
        self.fn_ids[node] = name
        return name
      end
      if cls == AnnotateNode then
        local name = self:compile_node(node.base_type)
        self.fn_ids[node] = name
        return name
      end
      self.fn_count = self.fn_count + 1
      local name = "t" .. tostring(self.fn_count)
      self.fn_ids[node] = name
      local buffer = { }
      local emit
      emit = function(line)
        return table.insert(buffer, line)
      end
      table.insert(self.node_stack, node)
      local inline
      if self:is_pure(node) then
        inline = self:inline_predicate(node, "value", "state")
      end
      if inline then
        emit("if " .. tostring(inline) .. " then return value, state end")
        emit("return FailedTransform")
      elseif node._compile_transform then
        emit("do")
        node:_compile_transform(self, emit)
        emit("end")
        emit("return FailedTransform")
      else
        local handler_name = self.handlers[cls]
        local handler
        if handler_name then
          handler = self[handler_name]
        else
          handler = self.compile_fallback
        end
        handler(self, node, emit)
      end
      table.remove(self.node_stack)
      self:push(tostring(name) .. " = function(value, state)")
      for _index_0 = 1, #buffer do
        local line = buffer[_index_0]
        self:push(line)
      end
      self:push("end")
      return name
    end,
    assemble_definitions = function(self, buf)
      for i, expr in ipairs(self.consts) do
        table.insert(buf, "local c" .. tostring(i) .. " = " .. tostring(expr))
      end
      if self.fn_count > 0 then
        table.insert(buf, "local " .. table.concat((function()
          local _accum_0 = { }
          local _len_0 = 1
          for i = 1, self.fn_count do
            _accum_0[_len_0] = "t" .. tostring(i)
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)(), ", "))
      end
      local _list_0 = self.lines
      for _index_0 = 1, #_list_0 do
        local line = _list_0[_index_0]
        table.insert(buf, line)
      end
    end,
    uses_helper = function(self, name)
      local _list_0 = self.lines
      for _index_0 = 1, #_list_0 do
        local line = _list_0[_index_0]
        if line:find(name, 1, true) then
          return true
        end
      end
      return false
    end,
    assemble = function(self, main_name)
      local buf = {
        "local FailedTransform, clone_state, refs = ...",
        "local type, pairs, ipairs, next, tostring = type, pairs, ipairs, next, tostring",
        "local getmetatable, setmetatable = getmetatable, setmetatable",
        "local string_match = string.match"
      }
      if #self.refs > 0 then
        local names = table.concat((function()
          local _accum_0 = { }
          local _len_0 = 1
          for i = 1, #self.refs do
            _accum_0[_len_0] = "r" .. tostring(i)
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)(), ", ")
        local exprs = table.concat((function()
          local _accum_0 = { }
          local _len_0 = 1
          for i = 1, #self.refs do
            _accum_0[_len_0] = "refs[" .. tostring(i) .. "]"
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)(), ", ")
        table.insert(buf, "local " .. tostring(names) .. " = " .. tostring(exprs))
      end
      if self:uses_helper("sorted_pairs(") then
        table.insert(buf, SORTED_PAIRS_SOURCE)
      end
      self:assemble_definitions(buf)
      table.insert(buf, "return " .. tostring(main_name))
      return table.concat(buf, "\n") .. "\n"
    end,
    assemble_module = function(self, main_name, error_message)
      assert(#self.refs == 0, "cannot assemble a standalone module with runtime references")
      local buf = {
        "-- generated by tableshape.codegen -- do not edit",
        "local type, pairs, ipairs, next, tostring = type, pairs, ipairs, next, tostring",
        "local getmetatable, setmetatable = getmetatable, setmetatable",
        "local string_match = string.match",
        "local FailedTransform = {}"
      }
      if self:uses_helper("clone_state(") then
        table.insert(buf, CLONE_STATE_SOURCE)
      end
      if self:uses_helper("sorted_pairs(") then
        table.insert(buf, SORTED_PAIRS_SOURCE)
      end
      self:assemble_definitions(buf)
      local err_expr = ("%q"):format(error_message)
      local footer = {
        "local check_value = function(value, state)",
        "local v, s = " .. tostring(main_name) .. "(value, state)",
        "if v == FailedTransform then return nil, " .. tostring(err_expr) .. " end",
        "if type(s) == 'table' then return s end",
        "return true",
        "end",
        "local transform = function(value, state)",
        "local v, s = " .. tostring(main_name) .. "(value, state)",
        "if v == FailedTransform then return nil, " .. tostring(err_expr) .. " end",
        "if type(s) == 'table' then return v, s end",
        "return v",
        "end",
        "return {",
        "check_value = check_value,",
        "transform = transform,",
        "repair = transform",
        "}"
      }
      for _index_0 = 1, #footer do
        local line = footer[_index_0]
        table.insert(buf, line)
      end
      return table.concat(buf, "\n") .. "\n"
    end,
    compile_fallback = function(self, node, emit)
      emit("local v, s = " .. tostring(self:ref(node)) .. ":_transform(value, state)")
      emit("if v == FailedTransform then return FailedTransform end")
      return emit("return v, s")
    end,
    compile_any = function(self, node, emit)
      return emit("return value, state")
    end,
    compile_literal = function(self, node, emit)
      emit("if value ~= " .. tostring(self:value_expr(node.value)) .. " then return FailedTransform end")
      return emit("return value, state")
    end,
    compile_type = function(self, node, emit)
      emit("if type(value) ~= " .. tostring(self:value_expr(node.t)) .. " then return FailedTransform end")
      if node.length_type then
        local fn = self:compile_node(node.length_type)
        emit("local lv, ls = " .. tostring(fn) .. "(#value, state)")
        emit("if lv == FailedTransform then return FailedTransform end")
        return emit("return value, ls")
      else
        return emit("return value, state")
      end
    end,
    compile_one_of = function(self, node, emit)
      if node.options_hash then
        emit("if " .. tostring(self:const(node.options_hash)) .. "[value] then return value, state end")
        emit("return FailedTransform")
        return 
      end
      local _list_0 = node.options
      for _index_0 = 1, #_list_0 do
        local option = _list_0[_index_0]
        if BaseType:is_base_type(option) then
          if self:is_pure(option) then
            emit("if " .. tostring(self:predicate_expr(option, "value", "state")) .. " then return value, state end")
          else
            local fn = self:compile_node(option)
            emit("do")
            emit("local v, s = " .. tostring(fn) .. "(value, state)")
            emit("if v ~= FailedTransform then return v, s end")
            emit("end")
          end
        else
          emit("if value == " .. tostring(self:value_expr(option)) .. " then return value, state end")
        end
      end
      return emit("return FailedTransform")
    end,
    compile_sequence_children = function(self, children, emit)
      emit("local v, s = value, state")
      for _index_0 = 1, #children do
        local child = children[_index_0]
        if self:is_pure(child) then
          emit("if not (" .. tostring(self:predicate_expr(child, "v", "s")) .. ") then return FailedTransform end")
        else
          local fn = self:compile_node(child)
          emit("v, s = " .. tostring(fn) .. "(v, s)")
          emit("if v == FailedTransform then return FailedTransform end")
        end
      end
      return emit("return v, s")
    end,
    compile_all_of = function(self, node, emit)
      return self:compile_sequence_children(node.types, emit)
    end,
    compile_sequence = function(self, node, emit)
      return self:compile_sequence_children(node.sequence, emit)
    end,
    compile_first_of = function(self, node, emit)
      local _list_0 = node.options
      for _index_0 = 1, #_list_0 do
        local option = _list_0[_index_0]
        if self:is_pure(option) then
          emit("if " .. tostring(self:predicate_expr(option, "value", "state")) .. " then return value, state end")
        else
          local fn = self:compile_node(option)
          emit("do")
          emit("local v, s = " .. tostring(fn) .. "(value, state)")
          emit("if v ~= FailedTransform then return v, s end")
          emit("end")
        end
      end
      return emit("return FailedTransform")
    end,
    compile_transform = function(self, node, emit)
      if self:is_pure(node.node) then
        emit("if not (" .. tostring(self:predicate_expr(node.node, "value", "state")) .. ") then return FailedTransform end")
        emit("local v, s = value, state")
      else
        local fn = self:compile_node(node.node)
        emit("local v, s = " .. tostring(fn) .. "(value, state)")
        emit("if v == FailedTransform then return FailedTransform end")
      end
      if type(node.t_fn) == "function" then
        local t_ref = self:ref(node.t_fn)
        if node.with_state then
          return emit("return " .. tostring(t_ref) .. "(v, s), s")
        else
          return emit("return " .. tostring(t_ref) .. "(v), s")
        end
      else
        return emit("return " .. tostring(self:value_expr(node.t_fn)) .. ", s")
      end
    end,
    compile_optional = function(self, node, emit)
      emit("if value == nil then return value, state end")
      return emit("return " .. tostring(self:compile_node(node.base_type)) .. "(value, state)")
    end,
    compile_not = function(self, node, emit)
      emit("local v = " .. tostring(self:compile_node(node.base_type)) .. "(value, state)")
      emit("if v == FailedTransform then return value, state end")
      return emit("return FailedTransform")
    end,
    emit_set_tag = function(self, emit, state_name, key, value_name, tag_array)
      if tag_array then
        emit("local existing = " .. tostring(state_name) .. "[" .. tostring(key) .. "]")
        emit("if type(existing) == 'table' then")
        emit("local copy = {}")
        emit("for ek, ev in pairs(existing) do copy[ek] = ev end")
        emit("copy[#copy + 1] = " .. tostring(value_name))
        emit(tostring(state_name) .. "[" .. tostring(key) .. "] = copy")
        emit("else")
        emit(tostring(state_name) .. "[" .. tostring(key) .. "] = { " .. tostring(value_name) .. " }")
        return emit("end")
      else
        return emit(tostring(state_name) .. "[" .. tostring(key) .. "] = " .. tostring(value_name))
      end
    end,
    compile_tagged = function(self, node, emit)
      if self:is_pure(node.base_type) then
        emit("if not (" .. tostring(self:predicate_expr(node.base_type, "value", "state")) .. ") then return FailedTransform end")
        emit("local v, s = value, clone_state(state)")
      else
        local fn = self:compile_node(node.base_type)
        emit("local v, s = " .. tostring(fn) .. "(value, state)")
        emit("if v == FailedTransform then return FailedTransform end")
        emit("s = clone_state(s)")
      end
      if node.tag_type == "function" then
        emit(tostring(self:ref(node.tag_name)) .. "(s, v)")
      else
        self:emit_set_tag(emit, "s", self:value_expr(node.tag_name), "v", node.tag_array)
      end
      return emit("return v, s")
    end,
    compile_scope = function(self, node, emit)
      local fn = self:compile_node(node.base_type)
      emit("local v, scope = " .. tostring(fn) .. "(value, nil)")
      emit("if v == FailedTransform then return FailedTransform end")
      if node.tag_name then
        emit("state = clone_state(state)")
        if node.tag_type == "function" then
          emit(tostring(self:ref(node.tag_name)) .. "(state, v, scope)")
        else
          self:emit_set_tag(emit, "state", self:value_expr(node.tag_name), "scope", node.tag_array)
        end
      end
      return emit("return v, state")
    end,
    compile_shape = function(self, node, emit)
      emit("if type(value) ~= 'table' then return FailedTransform end")
      local shape_keys
      do
        local _tbl_0 = { }
        for k in pairs(node.shape) do
          _tbl_0[k] = true
        end
        shape_keys = _tbl_0
      end
      if self:is_pure(node) then
        for shape_key, shape_val in sorted_pairs(node.shape) do
          local key = self:value_expr(shape_key)
          emit("do")
          emit("local item = value[" .. tostring(key) .. "]")
          if BaseType:is_base_type(shape_val) then
            emit("if not (" .. tostring(self:predicate_expr(shape_val, "item", "state")) .. ") then return FailedTransform end")
          else
            emit("if item ~= " .. tostring(self:value_expr(shape_val)) .. " then return FailedTransform end")
          end
          emit("end")
        end
        if not (node.open) then
          local keys_ref = self:const(shape_keys)
          if node.extra_fields_type then
            emit("for rk in sorted_pairs(value) do")
            emit("if " .. tostring(keys_ref) .. "[rk] == nil then")
            emit("local tuple_in = {[rk] = value[rk]}")
            emit("if not (" .. tostring(self:predicate_expr(node.extra_fields_type, "tuple_in", "state")) .. ") then return FailedTransform end")
            emit("end")
            emit("end")
          else
            emit("for rk in pairs(value) do")
            emit("if " .. tostring(keys_ref) .. "[rk] == nil then return FailedTransform end")
            emit("end")
          end
        end
        emit("return value, state")
        return 
      end
      emit("local dirty = false")
      emit("local out = {}")
      for shape_key, shape_val in sorted_pairs(node.shape) do
        local key = self:value_expr(shape_key)
        emit("do")
        emit("local item = value[" .. tostring(key) .. "]")
        if BaseType:is_base_type(shape_val) then
          if self:is_pure(shape_val) then
            emit("if not (" .. tostring(self:predicate_expr(shape_val, "item", "state")) .. ") then return FailedTransform end")
            emit("out[" .. tostring(key) .. "] = item")
          else
            local fn = self:compile_node(shape_val)
            emit("local v, s = " .. tostring(fn) .. "(item, state)")
            emit("if v == FailedTransform then return FailedTransform end")
            emit("state = s")
            emit("if v ~= item then dirty = true end")
            emit("out[" .. tostring(key) .. "] = v")
          end
        else
          emit("if item ~= " .. tostring(self:value_expr(shape_val)) .. " then return FailedTransform end")
          emit("out[" .. tostring(key) .. "] = item")
        end
        emit("end")
      end
      local keys_ref = self:const(shape_keys)
      if node.open then
        emit("for rk in pairs(value) do")
        emit("if " .. tostring(keys_ref) .. "[rk] == nil then out[rk] = value[rk] end")
        emit("end")
      elseif node.extra_fields_type then
        local fn = self:compile_node(node.extra_fields_type)
        emit("for rk in sorted_pairs(value) do")
        emit("if " .. tostring(keys_ref) .. "[rk] == nil then")
        emit("local item = value[rk]")
        emit("local tuple, s = " .. tostring(fn) .. "({[rk] = item}, state)")
        emit("if tuple == FailedTransform then return FailedTransform end")
        emit("state = s")
        emit("local nk = tuple and next(tuple)")
        emit("if nk == nil then")
        emit("dirty = true")
        emit("else")
        emit("if nk ~= rk or tuple[nk] ~= item then dirty = true end")
        emit("out[nk] = tuple[nk]")
        emit("end")
        emit("end")
        emit("end")
      else
        emit("for rk in pairs(value) do")
        emit("if " .. tostring(keys_ref) .. "[rk] == nil then return FailedTransform end")
        emit("end")
      end
      emit("if dirty then return out, state end")
      return emit("return value, state")
    end,
    compile_array = function(self, node, emit)
      emit("if type(value) ~= 'table' then return FailedTransform end")
      emit("local k = 1")
      emit("for i in pairs(value) do")
      emit("if type(i) ~= 'number' then return FailedTransform end")
      emit("if i ~= k then return FailedTransform end")
      emit("k = k + 1")
      emit("end")
      return emit("return value, state")
    end,
    compile_array_of = function(self, node, emit)
      emit("if type(value) ~= 'table' then return FailedTransform end")
      local expected = node.expected
      if self:is_pure(node) then
        if node.length_type then
          emit("local len = #value")
          emit("if not (" .. tostring(self:predicate_expr(node.length_type, "len", "state")) .. ") then return FailedTransform end")
        end
        emit("for _, item in ipairs(value) do")
        if BaseType:is_base_type(expected) then
          emit("if not (" .. tostring(self:predicate_expr(expected, "item", "state")) .. ") then return FailedTransform end")
        else
          emit("if item ~= " .. tostring(self:value_expr(expected)) .. " then return FailedTransform end")
        end
        emit("end")
        emit("return value, state")
        return 
      end
      if node.length_type then
        local fn = self:compile_node(node.length_type)
        emit("do")
        emit("local lv, ls = " .. tostring(fn) .. "(#value, state)")
        emit("if lv == FailedTransform then return FailedTransform end")
        emit("state = ls")
        emit("end")
      end
      if BaseType:is_base_type(expected) then
        if self:is_pure(expected) then
          emit("for _, item in ipairs(value) do")
          emit("if not (" .. tostring(self:predicate_expr(expected, "item", "state")) .. ") then return FailedTransform end")
          emit("end")
          emit("return value, state")
          return 
        end
        local fn = self:compile_node(expected)
        emit("local copy, ci")
        emit("for idx, item in ipairs(value) do")
        emit("local skip = false")
        emit("local v, s = " .. tostring(fn) .. "(item, state)")
        emit("if v == FailedTransform then return FailedTransform end")
        emit("state = s")
        if not (node.keep_nils) then
          emit("if v == nil then skip = true end")
        end
        emit("if skip or v ~= item then")
        emit("if not copy then")
        emit("copy = {}")
        emit("for pi = 1, idx - 1 do copy[pi] = value[pi] end")
        emit("ci = idx")
        emit("end")
        emit("end")
        emit("if copy and not skip then")
        emit("copy[ci] = v")
        emit("ci = ci + 1")
        emit("end")
        emit("end")
        return emit("return copy or value, state")
      else
        emit("for idx, item in ipairs(value) do")
        emit("if item ~= " .. tostring(self:value_expr(expected)) .. " then return FailedTransform end")
        emit("end")
        return emit("return value, state")
      end
    end,
    compile_array_contains = function(self, node, emit)
      emit("if type(value) ~= 'table' then return FailedTransform end")
      if self:is_pure(node) then
        local cond
        if BaseType:is_base_type(node.contains) then
          cond = self:predicate_expr(node.contains, "item", "state")
        else
          cond = "item == " .. tostring(self:value_expr(node.contains))
        end
        emit("for _, item in ipairs(value) do")
        emit("if " .. tostring(cond) .. " then return value, state end")
        emit("end")
        emit("return FailedTransform")
        return 
      end
      emit("local contains = false")
      emit("local copy, ci")
      emit("for idx, item in ipairs(value) do")
      emit("local skip = false")
      emit("local transformed = item")
      if BaseType:is_base_type(node.contains) then
        local fn = self:compile_node(node.contains)
        emit("local v, s = " .. tostring(fn) .. "(item, state)")
        emit("if v ~= FailedTransform then")
        emit("state = s")
        emit("contains = true")
        if node.keep_nils then
          emit("transformed = v")
        else
          emit("if v == nil then skip = true else transformed = v end")
        end
        emit("end")
      else
        emit("if item == " .. tostring(self:value_expr(node.contains)) .. " then contains = true end")
      end
      emit("if skip or transformed ~= item then")
      emit("if not copy then")
      emit("copy = {}")
      emit("for pi = 1, idx - 1 do copy[pi] = value[pi] end")
      emit("ci = idx")
      emit("end")
      emit("end")
      emit("if copy and not skip then")
      emit("copy[ci] = transformed")
      emit("ci = ci + 1")
      emit("end")
      if node.short_circuit then
        emit("if contains then")
        emit("if copy then")
        emit("for ri = idx + 1, #value do")
        emit("copy[ci] = value[ri]")
        emit("ci = ci + 1")
        emit("end")
        emit("end")
        emit("break")
        emit("end")
      end
      emit("end")
      emit("if not contains then return FailedTransform end")
      return emit("return copy or value, state")
    end,
    compile_map_of = function(self, node, emit)
      emit("if type(value) ~= 'table' then return FailedTransform end")
      local emit_pair_check
      emit_pair_check = function(expected, var_name)
        if BaseType:is_base_type(expected) then
          if self:is_pure(expected) then
            emit("if not (" .. tostring(self:predicate_expr(expected, var_name, "state")) .. ") then return FailedTransform end")
            return false
          else
            local fn = self:compile_node(expected)
            emit("do")
            emit("local s")
            emit("new_" .. tostring(var_name) .. ", s = " .. tostring(fn) .. "(" .. tostring(var_name) .. ", state)")
            emit("if new_" .. tostring(var_name) .. " == FailedTransform then return FailedTransform end")
            emit("state = s")
            emit("end")
            return true
          end
        else
          emit("if " .. tostring(var_name) .. " ~= " .. tostring(self:value_expr(expected)) .. " then return FailedTransform end")
          return false
        end
      end
      if self:is_pure(node) then
        emit("for mk, mv in sorted_pairs(value) do")
        emit_pair_check(node.expected_key, "mk")
        emit_pair_check(node.expected_value, "mv")
        emit("end")
        emit("return value, state")
        return 
      end
      emit("local transformed = false")
      emit("local out = {}")
      emit("for mk, mv in sorted_pairs(value) do")
      emit("local new_mk, new_mv = mk, mv")
      emit_pair_check(node.expected_key, "mk")
      emit_pair_check(node.expected_value, "mv")
      emit("if new_mk ~= mk or new_mv ~= mv then transformed = true end")
      emit("if new_mk ~= nil then out[new_mk] = new_mv end")
      emit("end")
      emit("if transformed then return out, state end")
      return emit("return value, state")
    end,
    compile_range = function(self, node, emit)
      emit("if type(value) ~= " .. tostring(self:value_expr(node.value_type.t)) .. " then return FailedTransform end")
      emit("if value < " .. tostring(self:value_expr(node.left)) .. " or value > " .. tostring(self:value_expr(node.right)) .. " then return FailedTransform end")
      return emit("return value, state")
    end,
    compile_pattern = function(self, node, emit)
      if node.coerce then
        if BaseType:is_base_type(node.coerce) then
          local fn = self:compile_node(node.coerce)
          emit("local test = " .. tostring(fn) .. "(value, nil)")
          emit("if test == FailedTransform then return FailedTransform end")
        else
          emit("local test = tostring(value)")
        end
      else
        emit("local test = value")
      end
      emit("if type(test) ~= 'string' then return FailedTransform end")
      emit("if not string_match(test, " .. tostring(self:value_expr(node.pattern)) .. ") then return FailedTransform end")
      return emit("return value, state")
    end,
    compile_custom = function(self, node, emit)
      emit("if not " .. tostring(self:ref(node.fn)) .. "(value, state) then return FailedTransform end")
      return emit("return value, state")
    end,
    compile_clone = function(self, node, emit)
      emit("local vt = type(value)")
      emit("if vt == 'table' then")
      emit("local copy = {}")
      emit("for ck, cv in pairs(value) do copy[ck] = cv end")
      emit("local mt = getmetatable(value)")
      emit("if mt then setmetatable(copy, mt) end")
      emit("return copy, state")
      emit("elseif vt == 'nil' or vt == 'string' or vt == 'number' or vt == 'boolean' then")
      emit("return value, state")
      emit("end")
      return emit("return FailedTransform")
    end,
    compile_proxy = function(self, node, emit)
      local fn = self:compile_node(self:resolve_proxy(node))
      return emit("return " .. tostring(fn) .. "(value, state)")
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, opts)
      self.lines = { }
      self.refs = { }
      self.ref_ids = { }
      self.consts = { }
      self.const_ids = { }
      self.fn_ids = { }
      self.fn_count = 0
      self.pure_cache = { }
      self.pure_active = { }
      self.proxy_cache = { }
      self.node_stack = { }
      if opts then
        self.static = opts.static and true
      end
    end,
    __base = _base_0,
    __name = "Compiler"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Compiler = _class_0
end
local CompiledType
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    build_error = function(self)
      if not (self.error_message) then
        local ok, description = pcall(function()
          return self.node:_describe()
        end)
        if ok then
          self.error_message = "expected " .. tostring(description)
        else
          self.error_message = "failed to match compiled type"
        end
      end
      return self.error_message
    end,
    fail_error = function(self, value, state)
      if self.rerun_errors then
        local result, err = self.node:_transform(value, state)
        if result == FailedTransform then
          return err
        end
      end
      return self:build_error()
    end,
    _transform = function(self, value, state)
      local new_value, new_state = self.fn(value, state)
      if new_value == FailedTransform then
        return FailedTransform, self:fail_error(value, state)
      end
      return new_value, new_state
    end,
    check_value = function(self, value, state)
      local v, s = self.fn(value, state)
      if v == FailedTransform then
        return nil, self:fail_error(value, state)
      end
      if type(s) == "table" then
        return s
      else
        return true
      end
    end,
    transform = function(self, value, state)
      local v, s = self.fn(value, state)
      if v == FailedTransform then
        return nil, self:fail_error(value, state)
      end
      if type(s) == "table" then
        return v, s
      else
        return v
      end
    end,
    repair = function(self, ...)
      return self:transform(...)
    end,
    _describe = function(self)
      return self.node:_describe()
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, node, fn, code, opts)
      self.node, self.fn, self.code = node, fn, code
      if opts then
        self.rerun_errors = opts.rerun_errors and true
      end
    end,
    __base = _base_0,
    __name = "CompiledType",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CompiledType = _class_0
end
local generate_code
generate_code = function(node, opts)
  assert(BaseType:is_base_type(node), "expected type checker to compile")
  local compiler = Compiler(opts)
  local main_name = compiler:compile_node(node)
  return compiler:assemble(main_name), compiler.refs
end
local generate_module
generate_module = function(node)
  assert(BaseType:is_base_type(node), "expected type checker to compile")
  local compiler = Compiler({
    static = true
  })
  local main_name = compiler:compile_node(node)
  local ok, description = pcall(function()
    return node:_describe()
  end)
  local error_message
  if ok then
    error_message = "expected " .. tostring(description)
  else
    error_message = "failed to match compiled type"
  end
  return compiler:assemble_module(main_name, error_message)
end
local compile
compile = function(node, opts)
  local code, refs = generate_code(node, opts)
  local chunk = assert(load_code(code, "tableshape.codegen"))
  local fn = chunk(FailedTransform, clone_state, refs)
  return CompiledType(node, fn, code, opts)
end
return {
  compile = compile,
  generate_code = generate_code,
  generate_module = generate_module,
  CompiledType = CompiledType,
  Compiler = Compiler
}
