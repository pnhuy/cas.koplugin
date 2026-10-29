-- Domain-safe simplification and polynomial expansion.
--
-- Every rewrite here holds wherever the original expression is defined and
-- never makes an undefined point defined. Rewrites that would (x/x -> 1,
-- sqrt(x^2) -> x) are not applied; where a factor could cancel against its
-- reciprocal the result is kept and an assumption such as "x ≠ 0" is reported.

local ast = require("calccas.ast")
local errors = require("calccas.errors")
local limits = require("calccas.limits")
local printer = require("calccas.printer")

local M = {}

local MAX_PASSES = 5
local MAX_PRODUCT = 20000

local function is_int(node)
    return node.t == "num" and not node.approx and node.d == 1
end

local function is_zero(node)
    return node.t == "num" and not node.approx and node.n == 0
end

local function is_one(node)
    return node.t == "num" and not node.approx and node.n == 1 and node.d == 1
end

-- True when the node is finite and defined for every real input.
local TOTAL_FN = { sin = true, cos = true, exp = true, abs = true }

local function is_total(node)
    local t = node.t
    if t == "num" or t == "const" or t == "var" then
        return true
    elseif t == "add" or t == "mul" then
        for _, a in ipairs(node.args) do
            if not is_total(a) then
                return false
            end
        end
        return true
    elseif t == "pow" then
        return is_int(node.exp) and node.exp.n > 0 and is_total(node.base)
    end
    return TOTAL_FN[node.name] == true and is_total(node.arg)
end

local function nonzero_note(base)
    local text = printer.tostring(base)
    if base.t == "add" then
        text = "(" .. text .. ")"
    end
    return text .. " ≠ 0"
end

local function make_mul(coef, factors)
    if #factors == 0 then
        return coef
    end
    local args = {}
    if not is_one(coef) then
        args[1] = coef
    end
    for _, f in ipairs(factors) do
        args[#args + 1] = f
    end
    return ast.mul(args)
end

local function split_term(term)
    if term.t == "num" then
        return term, nil
    elseif term.t == "mul" then
        local coef, rest = ast.num(1), {}
        for _, a in ipairs(term.args) do
            if a.t == "num" then
                coef = a
            else
                rest[#rest + 1] = a
            end
        end
        return coef, ast.mul(rest)
    end
    return ast.num(1), term
end

local function collect_terms(args)
    local groups = {}
    for _, term in ipairs(args) do
        local coef, rest = split_term(term)
        local found
        for _, g in ipairs(groups) do
            if (g.rest == nil and rest == nil) or (g.rest and rest and ast.equal(g.rest, rest)) then
                found = g
                break
            end
        end
        if not found then
            found = { rest = rest, coefs = {} }
            groups[#groups + 1] = found
        end
        found.coefs[#found.coefs + 1] = coef
    end
    local out = {}
    for _, g in ipairs(groups) do
        local coef = ast.add(g.coefs)
        if not is_zero(coef) then
            out[#out + 1] = g.rest and ast.mul({ coef, g.rest }) or coef
        end
    end
    return ast.add(out)
end

local function pow_parts(factor)
    if factor.t == "pow" then
        return factor.base, factor.exp
    end
    return factor, ast.num(1)
end

local function add_power(out, base, k)
    if k == 1 then
        out[#out + 1] = base
    else
        out[#out + 1] = ast.pow(base, ast.num(k))
    end
end

local function collect_factors(args, notes)
    local coef, groups = ast.num(1), {}
    for _, f in ipairs(args) do
        if f.t == "num" then
            coef = ast.mul({ coef, f })
        else
            local base, exp = pow_parts(f)
            local found
            for _, g in ipairs(groups) do
                if ast.equal(g.base, base) then
                    found = g
                    break
                end
            end
            if not found then
                found = { base = base, exps = {} }
                groups[#groups + 1] = found
            end
            found.exps[#found.exps + 1] = { exp = exp, factor = f }
        end
    end
    local factors = {}
    for _, g in ipairs(groups) do
        local positive, negative, others = 0, 0, {}
        for _, e in ipairs(g.exps) do
            if is_int(e.exp) and e.exp.n > 0 then
                positive = positive + e.exp.n
            elseif is_int(e.exp) and e.exp.n < 0 then
                negative = negative + e.exp.n
            else
                others[#others + 1] = e.factor
            end
        end
        if positive > 0 then
            add_power(factors, g.base, positive)
        end
        if negative < 0 then
            add_power(factors, g.base, negative)
        end
        if positive > 0 and negative < 0 then
            notes[nonzero_note(g.base)] = true
        end
        for _, f in ipairs(others) do
            factors[#factors + 1] = f
        end
    end
    return coef, factors
end

local simplify_once

local function simplify_children(node, notes)
    local t = node.t
    if t == "add" or t == "mul" then
        local args = {}
        for i, a in ipairs(node.args) do
            args[i] = simplify_once(a, notes)
        end
        return args
    end
end

function simplify_once(node, notes)
    local t = node.t
    if t == "add" then
        return collect_terms(simplify_children(node, notes))
    elseif t == "mul" then
        local args = simplify_children(node, notes)
        local rebuilt = ast.mul(args)
        if rebuilt.t ~= "mul" then
            return rebuilt
        end
        local coef, factors = collect_factors(rebuilt.args, notes)
        if is_zero(coef) then
            for _, f in ipairs(factors) do
                if not is_total(f) then
                    return make_mul(coef, factors)
                end
            end
            return coef
        end
        return make_mul(coef, factors)
    elseif t == "pow" then
        local base, exp = simplify_once(node.base, notes), simplify_once(node.exp, notes)
        if is_one(exp) then
            return base
        elseif is_zero(exp) and base.t ~= "num" then
            notes[nonzero_note(base)] = true
            return ast.num(1)
        end
        return ast.pow(base, exp)
    elseif t == "fn" then
        return ast.fn(node.name, simplify_once(node.arg, notes))
    end
    return node
end

local function sorted_notes(notes)
    local list = {}
    for text in pairs(notes) do
        list[#list + 1] = text
    end
    table.sort(list)
    return list
end

function M.simplify(node)
    local notes = {}
    local current = node
    for _ = 1, MAX_PASSES do
        local nxt = simplify_once(current, notes)
        if ast.equal(nxt, current) then
            break
        end
        current = nxt
    end
    return current, sorted_notes(notes)
end

local function too_complex()
    return errors.new("too_complex", "expansion has more than " .. limits.max_terms .. " terms")
end

local function terms_of(node)
    if node.t == "add" then
        return node.args
    end
    return { node }
end

-- Collects like terms in a list of terms, failing past the term limit.
local function collect(list)
    local sum = M.simplify(ast.add(list))
    local terms = terms_of(sum)
    if #terms > limits.max_terms then
        return nil, too_complex()
    end
    return terms
end

local function product(a, b)
    if #a * #b > MAX_PRODUCT then
        return nil, too_complex()
    end
    local list = {}
    for _, x in ipairs(a) do
        for _, y in ipairs(b) do
            list[#list + 1] = ast.mul({ x, y })
        end
    end
    return collect(list)
end

local expand_node

local function expand_power(base, k)
    if k > limits.max_terms then
        return nil, too_complex()
    end
    local base_terms = terms_of(base)
    local acc = base_terms
    for _ = 2, k do
        local err
        acc, err = product(acc, base_terms)
        if not acc then
            return nil, err
        end
    end
    return ast.add(acc)
end

function expand_node(node)
    local t = node.t
    if t == "add" then
        local args = {}
        for i, a in ipairs(node.args) do
            local e, err = expand_node(a)
            if not e then
                return nil, err
            end
            args[i] = e
        end
        return ast.add(args)
    elseif t == "mul" then
        local acc = { ast.num(1) }
        for _, a in ipairs(node.args) do
            local e, err = expand_node(a)
            if not e then
                return nil, err
            end
            acc, err = product(acc, terms_of(e))
            if not acc then
                return nil, err
            end
        end
        return ast.add(acc)
    elseif t == "pow" then
        local base, err = expand_node(node.base)
        if not base then
            return nil, err
        end
        if base.t == "add" and is_int(node.exp) and node.exp.n >= 2 then
            return expand_power(base, node.exp.n)
        end
        return ast.pow(base, node.exp)
    elseif t == "fn" then
        local arg, err = expand_node(node.arg)
        if not arg then
            return nil, err
        end
        return ast.fn(node.name, arg)
    end
    return node
end

function M.expand(node)
    local expanded, err = expand_node(node)
    if not expanded then
        return nil, err
    end
    local result, notes = M.simplify(expanded)
    if result.t == "add" and #result.args > limits.max_terms then
        return nil, too_complex()
    end
    return result, notes
end

return M
