-- Exact reduction, numeric evaluation and closure compilation.
--
-- Two stages:
--   reduce(node, env)  exact: substitutes bound variables and folds exact
--                      arithmetic, raising definite math errors (1/0, 0^0,
--                      sqrt(-1)). Overflowing exact values stay symbolic.
--   value(node, env)   float: reports div_by_zero, domain, undefined and
--                      overflow for anything the exact stage left behind.
-- Nothing here uses load/loadstring: compile() returns a closure over the tree.

local ast = require("calccas.ast")
local errors = require("calccas.errors")
local R = require("calccas.rational")

local M = {}

local floor, abs, huge = math.floor, math.abs, math.huge
local MAX = 9007199254740991 -- 2^53 - 1, the exact-integer limit (see rational.lua)

local CONSTANTS = { pi = math.pi, e = math.exp(1) }

-- A tan() argument this close to a pole of cos() is treated as undefined.
local TAN_POLE = 1e-10

local function fail(kind, message)
    error(errors.new(kind, message), 0)
end

---------------------------------------------------------------- variables

local function collect(node, seen)
    local t = node.t
    if t == "var" then
        seen[node.name] = true
    elseif t == "add" or t == "mul" then
        for _, a in ipairs(node.args) do
            collect(a, seen)
        end
    elseif t == "pow" then
        collect(node.base, seen)
        collect(node.exp, seen)
    elseif t == "fn" then
        collect(node.arg, seen)
    end
end

function M.free_vars(node)
    local seen = {}
    collect(node, seen)
    local out = {}
    for name in pairs(seen) do
        out[#out + 1] = name
    end
    table.sort(out)
    return out
end

local function decimal_node(text)
    local sign, body = text:match("^([+-]?)(.*)$")
    local r = R.from_decimal(body)
    if not r then
        return nil
    end
    if sign == "-" then
        r = R.new(-r.n, r.d)
    end
    return ast.from_rational(r)
end

-- "a", "a/b" with optional sign; decimals allowed in both parts.
local function string_node(text)
    local s = text:gsub("%s+", "")
    local sign, a, b = s:match("^([+-]?)([%d%.]+)/([%d%.]+)$")
    if sign then
        local ra, rb = R.from_decimal(a), R.from_decimal(b)
        if not (ra and rb) then
            return nil
        end
        local q = R.div(ra, rb)
        if not q then
            return nil
        end
        if sign == "-" then
            q = R.new(-q.n, q.d)
        end
        return ast.from_rational(q)
    end
    return decimal_node(s)
end

local function to_node(name, value)
    if type(value) == "table" and value.t == "num" then
        return value
    elseif type(value) == "number" then
        if value ~= value then
            return nil, errors.new("domain", "value of '" .. name .. "' is not a number")
        elseif value == huge or value == -huge then
            return nil, errors.new("overflow", "value of '" .. name .. "' is too large")
        elseif value == floor(value) and abs(value) <= MAX then
            return ast.num(value)
        end
        -- Floats that print compactly (0.5, 0.1) were almost certainly typed
        -- as decimals, so keep them exact.
        local text = string.format("%.15g", value)
        return decimal_node(text) or ast.float(value)
    elseif type(value) == "string" then
        local node = string_node(value)
        if node then
            return node
        end
    end
    return nil, errors.new("syntax", "invalid value for '" .. tostring(name) .. "'")
end

-- vars: { name = number | "decimal or a/b" | num node }  ->  { name = num node }
function M.bind(vars)
    local env = {}
    if vars == nil then
        return env
    end
    local names = {}
    for name in pairs(vars) do
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local node, err = to_node(name, vars[name])
        if not node then
            return nil, err
        end
        env[name] = node
    end
    return env
end

---------------------------------------------------------------- exact stage

-- Exact integer q-th root of a non-negative integer, or nil.
local function iroot(n, q)
    if n == 0 or n == 1 then
        return n
    end
    if q > 53 then
        return nil
    end
    local v = floor(n ^ (1 / q) + 0.5)
    local p = 1
    for _ = 1, q do
        p = p * v
        if p > n then
            return nil
        end
    end
    if p == n then
        return v
    end
end

local function exact_num(node)
    return node.t == "num" and not node.approx
end

local reduce

local function reduce_pow(node, env)
    local b, e = reduce(node.base, env), reduce(node.exp, env)
    if not (exact_num(b) and exact_num(e)) then
        return ast.pow(b, e)
    end
    if e.d == 1 then
        if b.n == 0 and e.n <= 0 then
            if e.n == 0 then
                fail("undefined", "0^0 is undefined")
            end
            fail("div_by_zero", "division by zero")
        end
        return ast.pow(b, e)
    end
    if b.n < 0 then
        fail("domain", "fractional power of a negative number")
    end
    local rn, rd = iroot(b.n, e.d), iroot(b.d, e.d)
    if rn and rd then
        local root = R.new(rn, rd)
        local result, kind = R.pow_int(root, e.n)
        if result then
            return ast.from_rational(result)
        elseif kind == "div_by_zero" then
            fail("div_by_zero", "division by zero")
        end
    end
    return ast.pow(b, e)
end

local function reduce_fn(node, env)
    local a = reduce(node.arg, env)
    local name = node.name
    if exact_num(a) then
        if name == "sqrt" then
            if a.n < 0 then
                fail("domain", "square root of a negative number")
            end
            local r = R.sqrt(a)
            if r then
                return ast.from_rational(r)
            end
        elseif name == "abs" then
            return ast.num(abs(a.n), a.d)
        elseif name == "exp" then
            if a.n == 0 then
                return ast.num(1)
            end
        elseif name == "log" then
            if a.n <= 0 then
                fail("domain", "log needs a positive argument")
            end
            if a.n == 1 and a.d == 1 then
                return ast.num(0)
            end
        elseif name == "sin" or name == "tan" then
            if a.n == 0 then
                return ast.num(0)
            end
        elseif name == "cos" then
            if a.n == 0 then
                return ast.num(1)
            end
        end
    end
    return ast.fn(name, a)
end

function reduce(node, env)
    local t = node.t
    if t == "num" or t == "const" then
        return node
    elseif t == "var" then
        return env[node.name] or node
    elseif t == "add" or t == "mul" then
        local args = {}
        for i, a in ipairs(node.args) do
            args[i] = reduce(a, env)
        end
        return t == "add" and ast.add(args) or ast.mul(args)
    elseif t == "pow" then
        return reduce_pow(node, env)
    end
    return reduce_fn(node, env)
end

local function guarded(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    if errors.is(result) then
        return nil, result
    end
    error(result, 0)
end

-- env: { name = num node } as produced by bind().
function M.reduce(node, env)
    return guarded(reduce, node, env or {})
end

---------------------------------------------------------------- float stage

local function checked(v)
    if v ~= v then
        return nil, "domain", "result is not a real number"
    end
    if v == huge or v == -huge then
        return nil, "overflow", "result is too large"
    end
    return v
end

local function fpow(b, e)
    if b == 0 then
        if e == 0 then
            return nil, "undefined", "0^0 is undefined"
        elseif e < 0 then
            return nil, "div_by_zero", "division by zero"
        end
    end
    if b < 0 and e ~= floor(e) then
        return nil, "domain", "fractional power of a negative number"
    end
    return checked(b ^ e)
end

local FUNCTIONS = {
    sin = function(a) return checked(math.sin(a)) end,
    cos = function(a) return checked(math.cos(a)) end,
    tan = function(a)
        if abs(math.cos(a)) < TAN_POLE then
            return nil, "domain", "tan is undefined here"
        end
        return checked(math.tan(a))
    end,
    exp = function(a) return checked(math.exp(a)) end,
    log = function(a)
        if a <= 0 then
            return nil, "domain", "log needs a positive argument"
        end
        return checked(math.log(a))
    end,
    sqrt = function(a)
        if a < 0 then
            return nil, "domain", "square root of a negative number"
        end
        return checked(math.sqrt(a))
    end,
    abs = function(a) return abs(a) end,
}

-- Returns a number, or nil plus an error kind and message. env maps variable
-- names to floats.
local function fval(node, env)
    local t = node.t
    if t == "num" then
        return checked(node.approx and node.v or node.n / node.d)
    elseif t == "const" then
        return CONSTANTS[node.name]
    elseif t == "var" then
        local v = env[node.name]
        if v == nil then
            return nil, "unbound_variable", "unknown variable '" .. node.name .. "'"
        end
        return checked(v)
    elseif t == "add" or t == "mul" then
        local acc = t == "add" and 0 or 1
        for _, a in ipairs(node.args) do
            local v, kind, msg = fval(a, env)
            if v == nil then
                return nil, kind, msg
            end
            if t == "add" then
                acc = acc + v
            else
                acc = acc * v
            end
        end
        return checked(acc)
    elseif t == "pow" then
        local b, kind, msg = fval(node.base, env)
        if b == nil then
            return nil, kind, msg
        end
        local e
        e, kind, msg = fval(node.exp, env)
        if e == nil then
            return nil, kind, msg
        end
        return fpow(b, e)
    end
    local a, kind, msg = fval(node.arg, env)
    if a == nil then
        return nil, kind, msg
    end
    return FUNCTIONS[node.name](a)
end

-- env: { name = float }
function M.value(node, env)
    local v, kind, msg = fval(node, env or {})
    if v == nil then
        return nil, errors.new(kind, msg)
    end
    return v
end

---------------------------------------------------------------- public

-- Result: { exact = AST?, value = number?, assumptions = {}, free = {names} }
-- With free variables the result is symbolic (value is nil); otherwise value
-- is always set.
function M.evaluate(node, vars)
    local env, err = M.bind(vars)
    if not env then
        return nil, err
    end
    local reduced, rerr = M.reduce(node, env)
    if not reduced then
        return nil, rerr
    end
    local free = M.free_vars(reduced)
    if #free > 0 then
        return { exact = reduced, assumptions = {}, free = free }
    end
    local v, verr = M.value(reduced, {})
    if v == nil then
        return nil, verr
    end
    local exact = not (reduced.t == "num" and reduced.approx) and reduced or nil
    return { exact = exact, value = v, assumptions = {}, free = free }
end

-- Returns f(x) -> number | nil (nil = undefined at x), never raising.
function M.compile(node, varname)
    for _, name in ipairs(M.free_vars(node)) do
        if name ~= varname then
            return nil, errors.new("unbound_variable", "unknown variable '" .. name .. "'")
        end
    end
    local env = {}
    return function(x)
        env[varname] = x
        return (fval(node, env))
    end
end

return M
