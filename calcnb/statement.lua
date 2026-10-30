-- Splits a notebook cell into statements (see contracts/notebook-language.md).
-- An adapter over the language parser (`calccas.parse_program`): the grammar
-- lives there, this module only shapes each statement for the runner. Nothing
-- is ever passed to load/loadstring.

local calccas = require("calccas")
local errors = require("calccas.errors")
local registry = require("calccas.registry")

local M = {}

local MAX_NAME = 32
local RESERVED = registry.reserved_set()

M.RESERVED = RESERVED
M.MAX_NAME = MAX_NAME

local function range_error(line)
    local err = errors.new("range", "Invalid range")
    err.line = line
    return err
end

-- The numeric value of a constant range bound, or nil.
local function bound_value(node)
    local result = calccas.evaluate(node, {})
    local v = result and #result.free == 0 and result.value
    if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
        return v
    end
    return nil
end

local function plot_record(stmt)
    local node = stmt.node
    local args, srcs = {}, {}
    local range
    for i, a in ipairs(node.args) do
        if a.t == "range" then
            local lo, hi = bound_value(a.lo), bound_value(a.hi)
            if not (lo and hi and lo < hi) then
                return nil, range_error(stmt.line)
            end
            range = { lo = lo, hi = hi }
        else
            args[#args + 1] = a
            srcs[#srcs + 1] = stmt.arg_srcs and stmt.arg_srcs[i] or calccas.tostring(a)
        end
    end
    if #args == 0 then
        local err = errors.new("syntax", "plot needs at least one function")
        err.line = stmt.line
        return nil, err
    end
    return { kind = "plot", args = srcs, arg_nodes = args, range = range, line = stmt.line }
end

local function record(stmt)
    local node = stmt.node
    if node.t == "assign" then
        return { kind = "assign", name = node.name, text = stmt.rhs_src, node = node.value, line = stmt.line }
    elseif node.t == "funcdef" then
        return {
            kind = "funcdef", name = node.name, param = node.params[1], params = node.params,
            text = stmt.rhs_src, node = node.body, line = stmt.line,
        }
    elseif node.t == "call" and node.name == "plot" then
        return plot_record(stmt)
    end
    return { kind = "expr", text = stmt.src, node = node, line = stmt.line }
end

-- Returns a list of statements, or `nil, err` for the first bad statement
-- (`err.line` is its line). With `opts.lazy` a bad statement becomes
-- `{kind = "error", err = err, line = line}` in the list instead, so the
-- statements before it still run. `opts.env` supplies the known variables and
-- functions.
function M.parse(source, opts)
    local env = opts and opts.env
    local lazy = opts and opts.lazy
    local parsed, perr = calccas.parse_program(source, env and { user_funcs = env.funcs, vars = env.vars } or nil)
    if not parsed then
        return nil, perr
    end
    local list = {}
    for _, stmt in ipairs(parsed) do
        local rec, err
        if stmt.err then
            err = stmt.err
        else
            rec, err = record(stmt)
        end
        if err then
            err.line = err.line or stmt.line
            if not lazy then
                return nil, err
            end
            rec = { kind = "error", err = err, line = err.line }
        end
        list[#list + 1] = rec
    end
    return list
end

return M
