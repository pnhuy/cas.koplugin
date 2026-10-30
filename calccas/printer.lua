-- Deterministic infix printer with minimal parentheses.
-- Sums print highest degree first with the constant last (x^2+2*x+1), signs
-- are folded into the operator (x-1), and negative-integer powers print as
-- quotients (x/y). The output parses back to the same tree.

local ast = require("calccas.ast")

local M = {}

local print_node

function M.format_number(v)
    if v == 0 then
        return "0"
    end
    return (string.format("%.9g", v))
end

local function is_exact_int(node)
    return node.t == "num" and not node.approx and node.d == 1
end

local function print_num(node)
    if node.approx then
        return M.format_number(node.v)
    end
    if node.d == 1 then
        return string.format("%d", node.n)
    end
    return string.format("%d/%d", node.n, node.d)
end

local function paren_if_add(node)
    local s = print_node(node)
    if node.t == "add" then
        return "(" .. s .. ")"
    end
    return s
end

-- Highest-degree-first ordering key for sums.
local function degree(node)
    local t = node.t
    if t == "var" then
        return 1
    elseif t == "pow" then
        if node.base.t == "var" and is_exact_int(node.exp) and node.exp.n > 0 then
            return node.exp.n
        end
        return 0
    elseif t == "mul" then
        local d = 0
        for _, a in ipairs(node.args) do
            d = d + degree(a)
        end
        return d
    end
    return 0
end

-- Variable name -> exponent for a monomial's plain-variable factors.
local function monomial(node, out)
    local t = node.t
    if t == "var" then
        out[node.name] = (out[node.name] or 0) + 1
    elseif t == "pow" and node.base.t == "var" and is_exact_int(node.exp) and node.exp.n > 0 then
        out[node.base.name] = (out[node.base.name] or 0) + node.exp.n
    elseif t == "mul" then
        for _, a in ipairs(node.args) do
            monomial(a, out)
        end
    end
    return out
end

-- Among equal-degree terms, the one with more of the alphabetically first
-- differing variable comes first: a^2*b before a*b^2.
local function monomial_before(a, b)
    local ma, mb = monomial(a, {}), monomial(b, {})
    local names, seen = {}, {}
    for _, m in ipairs({ ma, mb }) do
        for name in pairs(m) do
            if not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end
        end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local ea, eb = ma[name] or 0, mb[name] or 0
        if ea ~= eb then
            return ea > eb
        end
    end
    return nil
end

local function term_before(a, b)
    local da, db = degree(a), degree(b)
    if da ~= db then
        return da > db
    end
    local na, nb = a.t == "num", b.t == "num"
    if na ~= nb then
        return nb
    end
    local by_monomial = monomial_before(a, b)
    if by_monomial ~= nil then
        return by_monomial
    end
    return ast.compare(a, b) < 0
end

-- Plain-variable factors print in alphabetical order after constants and
-- before functions and other factors: 3*a^2*b, not 3*b*a^2.
local function factor_name(f)
    if f.t == "var" then
        return f.name
    elseif f.t == "pow" and f.base.t == "var" then
        return f.base.name
    end
end

local function order_factors(args, start)
    local lead, vars, rest = {}, {}, {}
    for i = start, #args do
        local f = args[i]
        if factor_name(f) then
            vars[#vars + 1] = { f = f, i = i }
        elseif f.t == "const" then
            lead[#lead + 1] = f
        else
            rest[#rest + 1] = f
        end
    end
    table.sort(vars, function(x, y)
        local nx, ny = factor_name(x.f), factor_name(y.f)
        if nx ~= ny then
            return nx < ny
        end
        return x.i < y.i
    end)
    local out = lead
    for _, v in ipairs(vars) do
        out[#out + 1] = v.f
    end
    for _, f in ipairs(rest) do
        out[#out + 1] = f
    end
    return out
end

local function print_add(node)
    local terms = {}
    for i, a in ipairs(node.args) do
        terms[i] = a
    end
    table.sort(terms, term_before)
    local out = print_node(terms[1])
    for i = 2, #terms do
        local s = print_node(terms[i])
        if s:sub(1, 1) == "-" then
            out = out .. s
        else
            out = out .. "+" .. s
        end
    end
    return out
end

local function print_product(args)
    local sign = ""
    local numer, denom = {}, {}
    local start = 1
    local first = args[1]
    if first.t == "num" then
        start = 2
        if first.approx then
            if first.v < 0 then
                sign = "-"
            end
            local a = math.abs(first.v)
            if a ~= 1 then
                numer[#numer + 1] = M.format_number(a)
            end
        else
            if first.n < 0 then
                sign = "-"
            end
            local an = math.abs(first.n)
            if an ~= 1 then
                numer[#numer + 1] = string.format("%d", an)
            end
            if first.d ~= 1 then
                denom[#denom + 1] = string.format("%d", first.d)
            end
        end
    end
    for _, f in ipairs(order_factors(args, start)) do
        if f.t == "pow" and is_exact_int(f.exp) and f.exp.n < 0 then
            local k = -f.exp.n
            if k == 1 then
                denom[#denom + 1] = paren_if_add(f.base)
            else
                denom[#denom + 1] = print_node({ t = "pow", base = f.base, exp = ast.num(k) })
            end
        else
            numer[#numer + 1] = paren_if_add(f)
        end
    end
    local out = sign .. (#numer > 0 and table.concat(numer, "*") or "1")
    if #denom == 1 then
        out = out .. "/" .. denom[1]
    elseif #denom > 1 then
        out = out .. "/(" .. table.concat(denom, "*") .. ")"
    end
    return out
end

local function print_pow(node)
    local b, e = node.base, node.exp
    local bs = print_node(b)
    local needs = b.t == "add" or b.t == "mul" or b.t == "pow"
    if b.t == "num" then
        needs = b.approx and b.v < 0 or (not b.approx and (b.d ~= 1 or b.n < 0))
    end
    if needs then
        bs = "(" .. bs .. ")"
    end
    local es = print_node(e)
    local plain = is_exact_int(e) and e.n >= 0
    if e.t == "var" or e.t == "const" or e.t == "fn" then
        plain = true
    end
    if not plain then
        es = "(" .. es .. ")"
    end
    return bs .. "^" .. es
end

function print_node(node)
    local t = node.t
    if t == "num" then
        return print_num(node)
    elseif t == "const" or t == "var" then
        return node.name
    elseif t == "add" then
        return print_add(node)
    elseif t == "mul" then
        return print_product(node.args)
    elseif t == "pow" then
        if is_exact_int(node.exp) and node.exp.n < 0 then
            return print_product({ node })
        end
        return print_pow(node)
    elseif t == "rel" then
        return print_node(node.lhs) .. " " .. node.op .. " " .. print_node(node.rhs)
    elseif t == "call" then
        local parts = {}
        for k, a in ipairs(node.args) do
            parts[k] = print_node(a)
        end
        return node.name .. "(" .. table.concat(parts, ", ") .. ")"
    elseif t == "range" then
        return node.var .. "=" .. print_node(node.lo) .. ".." .. print_node(node.hi)
    end
    return node.name .. "(" .. print_node(node.arg) .. ")"
end

M.tostring = print_node

-- Text shown to the user for an evaluation Result.
function M.result_text(res)
    if res.exact then
        local s = print_node(res.exact)
        if res.value ~= nil and res.exact.t ~= "num" then
            return s .. " ≈ " .. M.format_number(res.value)
        end
        return s
    end
    return M.format_number(res.value)
end

return M
