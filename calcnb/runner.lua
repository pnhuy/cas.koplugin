-- Executes a cell's source against a notebook environment and returns an
-- Output. Input is parsed by the CAS engine, never run as Lua. A multi-line
-- cell is atomic for the environment: a failing line restores it.

local ast = require("calccas.ast")
local calccas = require("calccas")
local eval = require("calccas.eval")
local output = require("calcnb.output")
local statement = require("calcnb.statement")

local M = {}

local function fail(err, line)
    return output.error(err, line)
end

-- Evaluates a parsed statement in the environment, returning the engine result.
local function evaluate(node, env)
    return calccas.evaluate(node, env.vars, env.funcs)
end

local function value_node(value)
    if type(value) == "table" and value.t then
        return value
    end
    return ast.float(value)
end

local function run_funcdef(stmt, env)
    local ok, serr = env:set_func(stmt.name, stmt.params, stmt.node)
    if not ok then
        return nil, serr
    end
    return output.text(stmt.name .. "(" .. table.concat(stmt.params, ", ") .. ") = " .. calccas.tostring(stmt.node))
end

local function run_assign(stmt, env)
    local result, err = evaluate(stmt.node, env)
    if not result then
        return nil, err
    end
    if #result.free > 0 then
        return nil, { kind = "unbound_variable", message = "value of '" .. stmt.name .. "' must be a number" }
    end
    local value = (result.exact and result.exact.t == "num") and result.exact or result.value
    local ok, serr = env:set_var(stmt.name, value)
    if not ok then
        return nil, serr
    end
    return output.text(stmt.name .. " = " .. result.text)
end

-- One plot argument -> `{label, ast}` with defined variables substituted. A
-- bare function name `f` plots `f(x)`.
local function plot_function(label, node, env)
    local entry = node.t == "var" and env.funcs[node.name]
    if entry then
        if #entry.params ~= 1 then
            return nil, { kind = "syntax", message = "`" .. node.name .. "` takes " .. #entry.params .. " arguments" }
        end
        node = ast.substitute(entry.body, entry.params[1], ast.var("x"))
    end
    for _, name in ipairs(eval.free_vars(node)) do
        if name ~= "x" and env.vars[name] ~= nil then
            node = ast.substitute(node, name, value_node(env.vars[name]))
        end
    end
    local fn, cerr = calccas.compile(node, "x")
    if not fn then
        return nil, cerr
    end
    return { label = label, ast = node }
end

local function run_plot(stmt, env)
    local functions = {}
    for i, label in ipairs(stmt.args) do
        local entry, err = plot_function(label, stmt.arg_nodes[i], env)
        if not entry then
            return nil, err
        end
        functions[i] = entry
    end
    local out, err = output.graph(functions, stmt.range)
    if not out then
        return nil, err
    end
    return out
end

local function run_expr(stmt, env)
    local result, err = evaluate(stmt.node, env)
    if not result then
        return nil, err
    end
    return output.value(result)
end

local function run_error(stmt)
    return nil, stmt.err
end

local RUNNERS = { funcdef = run_funcdef, assign = run_assign, plot = run_plot, expr = run_expr, error = run_error }

-- `opts.yield`: called between statements; returning `false` cancels the run.
function M.run(source, env, opts)
    local yield = opts and opts.yield
    local list, perr = statement.parse(source, { env = env, lazy = true })
    if not list then
        return fail(perr)
    end
    if #list == 0 then
        return { kind = "value", canonical = "", display = "", truncated = false, empty = true }
    end
    local snap = env:snapshot()
    local last
    for i, stmt in ipairs(list) do
        if i > 1 and yield and yield() == false then
            env:restore(snap)
            return fail({ kind = "cancelled", message = "Cancelled" })
        end
        local out, err = RUNNERS[stmt.kind](stmt, env)
        if not out then
            env:restore(snap)
            return fail(err, err.line or stmt.line)
        end
        last = out
    end
    return last
end

return M
