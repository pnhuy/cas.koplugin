-- Canonical expression tree (see data-model.md).
-- Constructors keep the invariants: add/mul are flattened, hold at most one
-- numeric constant (placed first), and order their other arguments
-- canonically. Exact numbers that overflow fall back to a flagged float.
-- Constructors only fold constants; neutral elements and like terms are left
-- for the simplifier.
-- Statement nodes (rel, call, range, assign, funcdef) are built as plain
-- records: they are never folded or reordered, only compared and traversed.

local R = require("calccas.rational")

local M = {}

local RANK = {
    num = 1, const = 2, var = 3, pow = 4, fn = 5, mul = 6, add = 7,
    rel = 8, call = 9, range = 10, assign = 11, funcdef = 12,
}

local function exact(r)
    return { t = "num", n = r.n, d = r.d }
end

function M.num(n, d)
    return exact(assert(R.new(n, d or 1)))
end

function M.from_rational(r)
    return exact(r)
end

function M.float(v)
    return { t = "num", approx = true, v = v }
end

function M.const(name)
    return { t = "const", name = name }
end

function M.var(name)
    return { t = "var", name = name }
end

function M.fn(name, arg)
    return { t = "fn", name = name, arg = arg }
end

-- `lhs == rhs`; never reduced to a truth value.
function M.rel(op, lhs, rhs)
    return { t = "rel", op = op, lhs = lhs, rhs = rhs }
end

-- A command or function call written with comma-separated arguments.
function M.call(name, args)
    return { t = "call", name = name, args = args }
end

-- `var=lo..hi`, only valid as the last argument of a call that allows it.
function M.range(var, lo, hi)
    return { t = "range", var = var, lo = lo, hi = hi }
end

function M.assign(name, value)
    return { t = "assign", name = name, value = value }
end

function M.funcdef(name, params, body)
    return { t = "funcdef", name = name, params = params, body = body }
end

function M.num_value(node)
    if node.approx then
        return node.v
    end
    return node.n / node.d
end

local function compare(a, b)
    local ra, rb = RANK[a.t], RANK[b.t]
    if ra ~= rb then
        return ra < rb and -1 or 1
    end
    local t = a.t
    if t == "num" then
        local va, vb = M.num_value(a), M.num_value(b)
        if va ~= vb then
            return va < vb and -1 or 1
        end
        if a.approx ~= b.approx then
            return a.approx and 1 or -1
        end
        if not a.approx then
            if a.n ~= b.n then
                return a.n < b.n and -1 or 1
            end
            if a.d ~= b.d then
                return a.d < b.d and -1 or 1
            end
        end
        return 0
    elseif t == "const" or t == "var" then
        if a.name == b.name then
            return 0
        end
        return a.name < b.name and -1 or 1
    elseif t == "pow" then
        local c = compare(a.base, b.base)
        if c ~= 0 then
            return c
        end
        return compare(a.exp, b.exp)
    elseif t == "fn" then
        if a.name ~= b.name then
            return a.name < b.name and -1 or 1
        end
        return compare(a.arg, b.arg)
    end
    if t == "rel" then
        if a.op ~= b.op then
            return a.op < b.op and -1 or 1
        end
        local c = compare(a.lhs, b.lhs)
        return c ~= 0 and c or compare(a.rhs, b.rhs)
    elseif t == "range" then
        if a.var ~= b.var then
            return a.var < b.var and -1 or 1
        end
        local c = compare(a.lo, b.lo)
        return c ~= 0 and c or compare(a.hi, b.hi)
    elseif t == "assign" then
        if a.name ~= b.name then
            return a.name < b.name and -1 or 1
        end
        return compare(a.value, b.value)
    elseif t == "funcdef" then
        if a.name ~= b.name then
            return a.name < b.name and -1 or 1
        end
        local pa, pb = table.concat(a.params, ","), table.concat(b.params, ",")
        if pa ~= pb then
            return pa < pb and -1 or 1
        end
        return compare(a.body, b.body)
    elseif t == "call" and a.name ~= b.name then
        return a.name < b.name and -1 or 1
    end
    local na, nb = #a.args, #b.args
    for i = 1, math.min(na, nb) do
        local c = compare(a.args[i], b.args[i])
        if c ~= 0 then
            return c
        end
    end
    if na ~= nb then
        return na < nb and -1 or 1
    end
    return 0
end

M.compare = compare

function M.equal(a, b)
    return compare(a, b) == 0
end

local function fold(nums, start, exact_op, float_op)
    local acc, fv = start, nil
    for _, node in ipairs(nums) do
        if fv == nil and not node.approx then
            local r = exact_op(acc, { n = node.n, d = node.d })
            if r then
                acc = r
            else
                fv = float_op(R.to_number(acc), M.num_value(node))
            end
        else
            fv = float_op(fv or R.to_number(acc), M.num_value(node))
        end
    end
    if fv then
        return M.float(fv)
    end
    return exact(acc)
end

local function build(t, args, start, exact_op, float_op)
    local flat, nums = {}, {}
    local function push(node)
        if node.t == "num" then
            nums[#nums + 1] = node
        else
            flat[#flat + 1] = node
        end
    end
    for _, a in ipairs(args) do
        if a.t == t then
            for _, child in ipairs(a.args) do
                push(child)
            end
        else
            push(a)
        end
    end
    if #nums == 0 and #flat == 0 then
        return exact(start)
    end
    if #nums == 0 and #flat == 1 then
        return flat[1]
    end
    table.sort(flat, function(x, y) return compare(x, y) < 0 end)
    if #nums > 0 then
        local folded = fold(nums, start, exact_op, float_op)
        if #flat == 0 then
            return folded
        end
        table.insert(flat, 1, folded)
    end
    return { t = t, args = flat }
end

function M.add(args)
    return build("add", args, { n = 0, d = 1 }, R.add, function(a, b) return a + b end)
end

function M.mul(args)
    return build("mul", args, { n = 1, d = 1 }, R.mul, function(a, b) return a * b end)
end

-- Integer powers are normalized so equal expressions share one form:
--   * exact number ^ integer folds (unless it divides by zero, overflows or is 0^0);
--   * (a*b)^k becomes a^k * b^k and (b^m)^k becomes b^(m*k) for integer k, m != 0,
--     which hold for every real value where either side is defined.
-- Anything else stays a pow node for the evaluator.
function M.pow(base, exp)
    if exp.t == "num" and not exp.approx and exp.d == 1 then
        local k = exp.n
        if base.t == "num" and not base.approx then
            if not (base.n == 0 and k <= 0) then
                local r = R.pow_int({ n = base.n, d = base.d }, k)
                if r then
                    return exact(r)
                end
            end
        elseif k ~= 0 and base.t == "mul" then
            local parts = {}
            for _, a in ipairs(base.args) do
                parts[#parts + 1] = M.pow(a, exp)
            end
            return M.mul(parts)
        elseif k ~= 0 and base.t == "pow" and base.exp.t == "num" and not base.exp.approx
            and base.exp.d == 1 then
            local product = R.mul({ n = base.exp.n, d = 1 }, { n = k, d = 1 })
            if product then
                return M.pow(base.base, exact(product))
            end
        end
    end
    return { t = "pow", base = base, exp = exp }
end

function M.neg(x)
    return M.mul({ M.num(-1), x })
end

function M.sub(a, b)
    return M.add({ a, M.neg(b) })
end

function M.div(a, b)
    return M.mul({ a, M.pow(b, M.num(-1)) })
end

local function children(node)
    local t = node.t
    if t == "add" or t == "mul" then
        return node.args
    elseif t == "pow" then
        return { node.base, node.exp }
    elseif t == "fn" then
        return { node.arg }
    elseif t == "rel" then
        return { node.lhs, node.rhs }
    elseif t == "call" then
        return node.args
    elseif t == "range" then
        return { node.lo, node.hi }
    elseif t == "assign" then
        return { node.value }
    elseif t == "funcdef" then
        return { node.body }
    end
    return {}
end

M.children = children

-- Replaces every variable named `name` with `replacement`, rebuilding through the
-- constructors so the canonical invariants hold.
function M.substitute(node, name, replacement)
    local t = node.t
    if t == "var" then
        return node.name == name and replacement or node
    elseif t == "add" or t == "mul" then
        local args = {}
        for i, a in ipairs(node.args) do
            args[i] = M.substitute(a, name, replacement)
        end
        return t == "add" and M.add(args) or M.mul(args)
    elseif t == "pow" then
        return M.pow(M.substitute(node.base, name, replacement), M.substitute(node.exp, name, replacement))
    elseif t == "fn" then
        return M.fn(node.name, M.substitute(node.arg, name, replacement))
    elseif t == "rel" then
        return M.rel(node.op, M.substitute(node.lhs, name, replacement), M.substitute(node.rhs, name, replacement))
    elseif t == "call" then
        local args = {}
        for i, a in ipairs(node.args) do
            args[i] = M.substitute(a, name, replacement)
        end
        return M.call(node.name, args)
    elseif t == "range" then
        return M.range(node.var, M.substitute(node.lo, name, replacement), M.substitute(node.hi, name, replacement))
    elseif t == "assign" then
        return M.assign(node.name, M.substitute(node.value, name, replacement))
    elseif t == "funcdef" then
        for _, p in ipairs(node.params) do
            if p == name then
                return node
            end
        end
        return M.funcdef(node.name, node.params, M.substitute(node.body, name, replacement))
    end
    return node
end

-- Deterministic S-expression text, e.g. `(add 1 (mul 2 x))`; used by the
-- conformance tests to compare structure without a printer.
function M.dump(node)
    local t = node.t
    if t == "num" then
        if node.approx then
            return "~" .. string.format("%.15g", node.v)
        end
        return node.d == 1 and string.format("%d", node.n) or string.format("%d/%d", node.n, node.d)
    elseif t == "const" or t == "var" then
        return node.name
    elseif t == "fn" then
        return "(" .. node.name .. " " .. M.dump(node.arg) .. ")"
    elseif t == "pow" then
        return "(pow " .. M.dump(node.base) .. " " .. M.dump(node.exp) .. ")"
    elseif t == "rel" then
        return "(rel " .. node.op .. " " .. M.dump(node.lhs) .. " " .. M.dump(node.rhs) .. ")"
    elseif t == "range" then
        return "(range " .. node.var .. " " .. M.dump(node.lo) .. " " .. M.dump(node.hi) .. ")"
    elseif t == "assign" then
        return "(assign " .. node.name .. " " .. M.dump(node.value) .. ")"
    elseif t == "funcdef" then
        return "(funcdef " .. node.name .. " (" .. table.concat(node.params, " ") .. ") " .. M.dump(node.body) .. ")"
    end
    local parts = { t == "call" and ("call " .. node.name) or t }
    for _, a in ipairs(node.args) do
        parts[#parts + 1] = M.dump(a)
    end
    return "(" .. table.concat(parts, " ") .. ")"
end

function M.count(node)
    local total = 1
    for _, child in ipairs(children(node)) do
        total = total + M.count(child)
    end
    return total
end

function M.depth(node)
    local deepest = 0
    for _, child in ipairs(children(node)) do
        deepest = math.max(deepest, M.depth(child))
    end
    return deepest + 1
end

return M
