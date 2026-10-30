-- CAS facade. Every public function returns `result` or `nil, err` and never
-- throws: an unexpected Lua error is reported as an `internal` error.

local errors = require("calccas.errors")
local eval = require("calccas.eval")
local limits = require("calccas.limits")
local parser = require("calccas.parser")
local printer = require("calccas.printer")
local registry = require("calccas.registry")
local simplifier = require("calccas.simplify")

local M = {}

M.LANGUAGE_VERSION = registry.VERSION

local function guard(fn)
    return function(...)
        local ok, a, b = pcall(fn, ...)
        if ok then
            return a, b
        end
        return nil, errors.new("internal", tostring(a))
    end
end

-- Accepts expression text or an already parsed AST.
local function as_ast(input, user_funcs)
    if type(input) == "table" and input.t then
        return input
    end
    return parser.parse(input, user_funcs and { user_funcs = user_funcs } or nil)
end

-- `overrides` is passed to the parser (limits, `user_funcs`).
M.parse = guard(function(text, overrides)
    return parser.parse(text, overrides)
end)

-- Parses a whole cell into statements; see calccas.parser.parse_program.
M.parse_program = guard(function(text, overrides)
    return parser.parse_program(text, overrides)
end)

-- Sorted names of the supported built-in functions.
function M.functions()
    return registry.functions()
end

local function symbolic_result(node, notes)
    return {
        exact = node,
        assumptions = notes,
        free = eval.free_vars(node),
        text = printer.tostring(node),
    }
end

local function reject_relation(node)
    if node.t == "rel" or node.t == "call" then
        return errors.new("unsupported", "this operation does not apply to an equation or command")
    end
end

M.simplify = guard(function(input, user_funcs)
    local node, err = as_ast(input, user_funcs)
    if not node then
        return nil, err
    end
    err = reject_relation(node)
    if err then
        return nil, err
    end
    return symbolic_result(simplifier.simplify(node))
end)

M.expand = guard(function(input, user_funcs)
    local node, err = as_ast(input, user_funcs)
    if not node then
        return nil, err
    end
    err = reject_relation(node)
    if err then
        return nil, err
    end
    local expanded, notes = simplifier.expand(node)
    if not expanded then
        return nil, notes
    end
    return symbolic_result(expanded, notes)
end)

-- `user_funcs` (optional): name -> `{param, body}` callable as `name(arg)`.
M.evaluate = guard(function(input, vars, user_funcs)
    local node, err = as_ast(input, user_funcs)
    if not node then
        return nil, err
    end
    if node.t == "call" then
        local entry = registry.get(node.name)
        if entry.status == "reserved" then
            return nil, errors.new("unsupported",
                "`" .. node.name .. "` is reserved for a future version; not available in language " .. registry.VERSION)
        elseif node.name == "plot" then
            return nil, errors.new("unsupported", "plot must be run as its own statement")
        end
        return M[node.name](node.args[1], user_funcs)
    end
    local result, eerr = eval.evaluate(node, vars)
    if not result then
        return nil, eerr
    end
    result.text = printer.result_text(result)
    return result
end)

M.compile = guard(function(input, varname)
    local node, err = as_ast(input)
    if not node then
        return nil, err
    end
    return eval.compile(node, varname or "x")
end)

M.tostring = printer.tostring

-- "x=2, y=1/2; z=0.25" -> { x = num node, ... }. Values may be expressions
-- without free variables.
M.parse_assignments = guard(function(text)
    if type(text) ~= "string" then
        return nil, errors.new("syntax", "assignments must be text")
    end
    if #text > limits.max_chars then
        return nil, errors.new("too_complex", "assignments are too long")
    end
    local vars = {}
    if text:match("^%s*$") then
        return vars
    end
    local offset = 1
    for segment in (text .. ","):gmatch("([^,;]*)[,;]") do
        local name, value = segment:match("^%s*([A-Za-z][A-Za-z0-9_]*)%s*=%s*(.-)%s*$")
        if not name or value == "" then
            return nil, errors.new("syntax", "expected name=value", offset)
        end
        if registry.is_reserved(name) then
            return nil, errors.new("syntax", "'" .. name .. "' cannot be assigned", offset)
        end
        local result, err = M.evaluate(value)
        if not result then
            return nil, err
        end
        if #result.free > 0 then
            return nil, errors.new("unbound_variable", "value of '" .. name .. "' must be a number", offset)
        end
        if result.exact and result.exact.t == "num" then
            vars[name] = result.exact
        else
            vars[name] = result.value
        end
        offset = offset + #segment + 1
    end
    return vars
end)

return M
