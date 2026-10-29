-- CAS facade. Every public function returns `result` or `nil, err` and never
-- throws: an unexpected Lua error is reported as an `internal` error.

local errors = require("calccas.errors")
local eval = require("calccas.eval")
local limits = require("calccas.limits")
local parser = require("calccas.parser")
local printer = require("calccas.printer")
local simplifier = require("calccas.simplify")

local M = {}

local FUNCTION_NAMES = { sin = true, cos = true, tan = true, exp = true, log = true, ln = true, sqrt = true, abs = true }

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
local function as_ast(input)
    if type(input) == "table" and input.t then
        return input
    end
    return parser.parse(input)
end

M.parse = guard(function(text)
    return parser.parse(text)
end)

local function symbolic_result(node, notes)
    return {
        exact = node,
        assumptions = notes,
        free = eval.free_vars(node),
        text = printer.tostring(node),
    }
end

M.simplify = guard(function(input)
    local node, err = as_ast(input)
    if not node then
        return nil, err
    end
    return symbolic_result(simplifier.simplify(node))
end)

M.expand = guard(function(input)
    local node, err = as_ast(input)
    if not node then
        return nil, err
    end
    local expanded, notes = simplifier.expand(node)
    if not expanded then
        return nil, notes
    end
    return symbolic_result(expanded, notes)
end)

-- "simplify(<expr>)" / "expand(<expr>)" spanning the whole input. Returns the
-- wrapper name and the inner text, or nil when the text is not such a call.
local function split_wrapper(text)
    if type(text) ~= "string" then
        return nil
    end
    local name, rest = text:match("^%s*(%a+)%s*(%(.*)$")
    if name ~= "simplify" and name ~= "expand" then
        return nil
    end
    local depth = 0
    for i = 1, #rest do
        local c = rest:sub(i, i)
        if c == "(" then
            depth = depth + 1
        elseif c == ")" then
            depth = depth - 1
            if depth == 0 then
                if rest:sub(i + 1):match("^%s*$") then
                    return name, rest:sub(2, i - 1)
                end
                return nil
            end
        end
    end
    return nil
end

M.evaluate = guard(function(input, vars)
    local wrapper, inner = split_wrapper(input)
    if wrapper then
        return M[wrapper](inner)
    end
    local node, err = as_ast(input)
    if not node then
        return nil, err
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
        if name == "pi" or name == "e" or FUNCTION_NAMES[name] then
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
